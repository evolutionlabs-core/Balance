class Llm::Chat < ApplicationRecord
  self.table_name = "llm_chats"

  CONTEXT_WINDOW_TOKENS = 200_000
  COMPACTION_THRESHOLD = 0.7
  TAIL_BUDGET_TOKENS = (CONTEXT_WINDOW_TOKENS * 0.6).to_i
  PRUNE_PROTECT_TOKENS = 40_000
  CHARS_PER_TOKEN = 4
  MESSAGE_OVERHEAD_TOKENS = 5

  belongs_to :workspace
  has_many :proposals, foreign_key: :llm_chat_id, dependent: :destroy
  has_many :llm_activities, class_name: "Llm::Activity", foreign_key: :llm_chat_id, dependent: :destroy
  has_many :llm_turns, class_name: "Llm::Turn", foreign_key: :llm_chat_id, dependent: :destroy

  attr_accessor :active_turn

  acts_as_chat messages: :llm_messages, message_class: "Llm::Message", messages_foreign_key: :llm_chat_id

  def to_param
    uuid
  end

  def self.estimated_tokens(text)
    (text.to_s.length.to_f / CHARS_PER_TOKEN).ceil + MESSAGE_OVERHEAD_TOKENS
  end

  def timeline
    items = []
    visible_messages.each { |message| items << { type: :message, record: message, at: message.created_at } }
    llm_activities.each { |activity| items << { type: :activity, record: activity, at: activity.created_at } }
    persisted_tool_calls.each { |tool_call| items << { type: :tool_call, record: tool_call, at: tool_call.created_at } }
    proposals.each { |proposal| items << { type: :proposal, record: proposal, at: proposal.created_at } }
    llm_turns.unfinished.each { |turn| items << { type: :turn, record: turn, at: turn.created_at } }
    items.sort_by { |item| item[:at] }
  end

  def visible_messages
    llm_messages.where(role: "user")
      .or(llm_messages.where(role: "assistant", internal: false))
      .where.not(content: [ nil, "" ])
      .order(:created_at, :id)
  end

  def awaiting_response?
    llm_turns.unfinished.exists?
  end

  def persisted_tool_calls
    scope = Llm::ToolCall.joins(:llm_message)
      .where(llm_messages: { llm_chat_id: id })

    visible_tools = %w[list_accounts list_journal_entries get_balance_summary check_proposal_status confirm_proposal]
    proposal_tools = scope.where(name: %w[propose_entry propose_account propose_reversal])
      .where(message_id: proposals.where.not(llm_message_id: nil).select(:llm_message_id))

    scope.where(name: visible_tools).or(proposal_tools)
      .order(:created_at, :id)
  end

  def latest_proposal(type = nil)
    scope = proposals.proposed
    scope = scope.by_type(type) if type
    scope.order(version: :desc).first
  end

  def start_turn(content)
    create_turn(role: "user", content: content)
  end

  def resume_turn(content)
    create_turn(role: "system", content: content)
  end

  def create_turn(role:, content:)
    transaction do
      message = llm_messages.create!(role: role, content: content)
      turn = llm_turns.create!(user_message: message)
      LlmChatResponseJob.perform_later(id, turn.id)
      message
    end
  end

  def active_context_messages
    llm_messages.order(:created_at, :id).to_a
  end

  # A bare RubyLLM chat on this chat's model, outside the persisted
  # conversation and without the ledger tools.
  def detached_llm_chat
    RubyLLM.chat(model: model_id || RubyLLM.config.default_model, provider: (provider || "openai").to_sym, assume_model_exists: true)
  end

  def derive_title_from(prompt)
    truncated = prompt.to_s.squish.delete_suffix(".").truncate(60, separator: " ", omission: "…")
    self.title = truncated.present? ? truncated[0].upcase + truncated[1..] : "New chat"
  end

  def needs_compaction?
    unsummarized.sum { |message| self.class.estimated_tokens(message.content) } > (CONTEXT_WINDOW_TOKENS * COMPACTION_THRESHOLD)
  end

  def current_summary
    unsummarized.where(role: "system").order(:id).to_a.drop(1).last
  end

  def foldable_head
    dialogue = unsummarized.where.not(role: "system").order(:created_at, :id).to_a
    dialogue - tail_fitting(dialogue)
  end

  private

  # Models served locally through LM Studio are usually missing from
  # RubyLLM's registry, so accept them as OpenAI-compatible models.
  def resolve_model
    super
  rescue RubyLLM::ModelNotFoundError
    self.provider ||= "openai"
    self.assume_model_exists = true
    super
  end

  def build_llm_chat
    self.assume_model_exists = true if model && !registered_model?
    super
  end

  def registered_model?
    RubyLLM.models.find(model.model_id, provider: model.provider)
    true
  rescue RubyLLM::ModelNotFoundError
    false
  end

  # RubyLLM replaces every system message with the new instructions on each
  # agent setup, which would destroy the compaction summary.
  def replace_persisted_system_instructions(instructions, cache_until_here: false)
    current = unsummarized.where(role: "system").order(:id).first

    if current
      current.update!(content: instructions) if current.content != instructions
    else
      llm_messages.create!(role: "system", content: instructions, cache_until_here: cache_until_here.present?)
    end
    llm_messages.reset
  end

  # RubyLLM sends every persisted message as history. Drop the messages
  # folded into a summary, merge the system messages, and mark the request
  # the current turn answers.
  def sync_messages(chat = @chat)
    super
    chat.messages = order_messages_for_llm(llm_messages.to_a)
    reapply_runtime_instructions(chat)
    chat
  end

  def order_messages_for_llm(messages)
    active = messages.reject(&:summarized_at)
    active = emphasize_current_request(active)
    system_messages, dialogue = active.partition { |message| message.role.to_s == "system" }
    return dialogue if system_messages.empty?

    merged = system_messages.first.dup
    merged.content = system_messages.map(&:content).join("\n\n")
    [ merged ] + dialogue
  end

  def emphasize_current_request(messages)
    current_message_id = active_turn&.user_message_id
    return messages unless current_message_id

    current_index = messages.index { |message| message.id == current_message_id }
    preceding_assistant_index = messages.first(current_index || 0).rindex do |message|
      message.role.to_s == "assistant" && message.content.present?
    end
    preceding_assistant = messages[preceding_assistant_index] if preceding_assistant_index
    preceding_user = messages.first(preceding_assistant_index || 0).reverse.find do |message|
      message.role.to_s == "user" && message.content.present?
    end

    messages.map do |message|
      next message unless message.id == current_message_id

      emphasized = message.dup
      emphasized.content = if message.role.to_s == "user" && preceding_assistant && preceding_user
        "[CURRENT EXCHANGE — RESPOND TO THIS]\n" \
          "User: #{preceding_user.content}\n" \
          "Assistant: #{preceding_assistant.content}\n" \
          "User: #{message.content}"
      elsif message.role.to_s == "user" && preceding_assistant
        "[CURRENT EXCHANGE — RESPOND TO THIS]\n" \
          "Assistant: #{preceding_assistant.content}\n" \
          "User: #{message.content}"
      else
        "[CURRENT REQUEST — RESPOND TO THIS]\n#{message.content}"
      end
      emphasized
    end
  end

  def unsummarized
    llm_messages.where(summarized_at: nil)
  end

  def tail_fitting(dialogue)
    kept = []
    budget = TAIL_BUDGET_TOKENS

    dialogue.reverse_each do |message|
      tokens = self.class.estimated_tokens(message.content)
      break if tokens > budget

      kept.unshift(message)
      budget -= tokens
    end

    kept.drop_while { |message| message.role.to_s != "user" }
  end
end
