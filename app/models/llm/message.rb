class Llm::Message < ApplicationRecord
  self.table_name = "llm_messages"

  acts_as_message chat: :llm_chat, chat_class: "Llm::Chat", chat_foreign_key: :llm_chat_id

  has_many :llm_tool_calls, -> { order(:created_at, :id) }, as: :message, class_name: "Llm::ToolCall"

  has_one :llm_turn, class_name: "Llm::Turn", foreign_key: :user_message_id, dependent: :destroy
  belongs_to :response_turn, class_name: "Llm::Turn", foreign_key: :llm_turn_id, optional: true

  attr_accessor :visible_response

  before_validation :assign_response_turn, :assign_visibility, on: :create
  after_create_commit :broadcast_append_if_visible
  after_update_commit :broadcast_replace_if_visible

  def broadcast_append_chunk(content)
    broadcast_append_to "llm_chat_#{llm_chat_id}",
      target: "llm_message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end

  private

  def assign_response_turn
    return if role == "user" || llm_turn_id.present?

    turn = Llm::Current.turn
    self.response_turn = turn if turn&.llm_chat_id == llm_chat_id
  end

  def assign_visibility
    return unless role == "assistant" && Llm::Current.turn

    self.internal = !(visible_response || Llm::Current.visible_response)
  end

  def broadcast_append_if_visible
    return unless role == "assistant" && !internal?

    broadcast_append_to "llm_chat_#{llm_chat_id}",
      target: "llm_messages",
      partial: "llm/messages/assistant",
      locals: { assistant: self }
  end

  def broadcast_replace_if_visible
    return unless role == "assistant" && !internal? && content.present?

    broadcast_replace_to "llm_chat_#{llm_chat_id}",
      partial: "llm/messages/assistant",
      locals: { assistant: self }
  end
end
