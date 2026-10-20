class Llm::TitleGenerator
  MAX_LENGTH = 52
  REJECT_LONGER_THAN = 140

  INSTRUCTIONS = <<~PROMPT.freeze
    Write a short title for a bookkeeping chat that opens with the message below.

    Rules:
    - 3 to 6 words, under #{MAX_LENGTH} characters
    - name the transaction or question, not the person writing it
    - no quotes, no trailing period, no preamble
    - reply with the title only

    Message:
    %{prompt}
  PROMPT

  def initialize(llm_chat)
    @llm_chat = llm_chat
  end

  def call
    prompt = first_user_prompt
    return if prompt.blank?

    sanitize(ask(prompt))
  rescue StandardError => e
    Rails.logger.warn("Llm::TitleGenerator failed for chat #{@llm_chat.id}: #{e.class}: #{e.message}")
    nil
  end

  private
    def first_user_prompt
      @llm_chat.llm_messages.where(role: "user").order(:created_at, :id).first&.content
    end

    # A bare RubyLLM chat, so titling never lands in the conversation the user sees
    # or picks up the ledger tools.
    def ask(prompt)
      @llm_chat.detached_llm_chat.with_temperature(0.2).ask(format(INSTRUCTIONS, prompt: prompt.to_s.truncate(500))).content
    end

    def sanitize(raw)
      text = strip_reasoning(raw.to_s)
      text = text.lines.map(&:strip).find(&:present?).to_s

      text = text.sub(/\A#+\s*/, "")
      text = text.sub(/\A(?:chat\s+)?title\s*[:\-–—]\s*/i, "")
      text = text.gsub(/\A["'“”‘’`*]+|["'“”‘’`*]+\z/, "")
      text = text.squish.delete_suffix(".")

      return if text.blank? || text.length > REJECT_LONGER_THAN

      text = text.truncate(MAX_LENGTH, separator: " ", omission: "…")
      text[0].upcase + text[1..].to_s
    end

    # Local reasoning models wrap their scratchpad in <think> tags, and an unbalanced
    # opening tag means the whole reply was reasoning.
    def strip_reasoning(raw)
      without_blocks = raw.gsub(%r{<think>.*?</think>}mi, "")
      without_blocks = without_blocks.split(%r{</think>}i).last.to_s if without_blocks.match?(/<think>/i)
      without_blocks
    end
end
