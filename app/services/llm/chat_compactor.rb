class Llm::ChatCompactor
  MAX_SUMMARY_TOKENS = 5_000
  MAX_HEAD_TOKENS = 2_000

  PROMPT = <<~PROMPT.freeze
    Compress the conversation segment below into a dense summary for a bookkeeping
    assistant. The assistant must answer follow-up questions about these transactions,
    accounts, and decisions without ever seeing the original messages.

    Preserve facts: account names and balances, journal entries (amounts, accounts,
    dates), proposal and approval statuses, reversals, user preferences, and open items.
    Omit: tool call plumbing, repeated explanations, and reasoning traces.
    Keep the summary under #{MAX_SUMMARY_TOKENS} tokens.

    <previous-summary>
    %{summary}
    </previous-summary>

    Conversation segment:
    %{head}
  PROMPT

  def initialize(chat, summarizer: nil)
    @chat = chat
    @summarizer = summarizer || method(:summarize)
  end

  def call
    Llm::ToolOutputPruner.new(@chat).call
    head = @chat.foldable_head
    return false if head.empty?

    summary = summarize_head(head)
    return false if summary.blank?

    Llm::Message.transaction do
      Llm::Message.where(id: head.map(&:id)).update_all(summarized_at: Time.current)
      @chat.llm_messages.create!(role: "system", content: summary)
    end

    true
  end

  private

  def summarize_head(head)
    summary = @chat.current_summary&.content.to_s

    chunks_of(head).each do |chunk|
      prompt = prompt_for(chunk, summary)
      result = @summarizer.call(prompt)
      result = @summarizer.call(prompt, temperature: 0.1) if result.blank?
      return result if result.blank?

      summary = result
    end

    summary
  end

  def chunks_of(head)
    chunks = []
    current = []
    tokens = 0

    head.each do |message|
      tokens += Llm::Chat.estimated_tokens(message.content)
      unless current.empty? || tokens <= MAX_HEAD_TOKENS
        chunks << current
        current = []
        tokens = Llm::Chat.estimated_tokens(message.content)
      end
      current << message
    end

    chunks << current unless current.empty?
    chunks
  end

  def prompt_for(head, summary)
    format(PROMPT,
      summary:,
      head: head.map { |message| render(message) }.join("\n"))
  end

  def render(message)
    role = message.role.to_s == "tool" ? "tool result" : message.role.to_s
    "[#{role}] #{message.content}"
  end

  def summarize(prompt, temperature: 0)
    @chat.detached_llm_chat
      .with_temperature(temperature)
      .with_max_output_tokens(MAX_SUMMARY_TOKENS)
      .ask(prompt).content.to_s
  rescue RubyLLM::BadRequestError
    ""
  end
end
