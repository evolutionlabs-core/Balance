class ChatUsage
  def initialize(llm_chat)
    @llm_chat = llm_chat
  end

  def reported? = total_tokens.positive?

  def input_tokens = @input_tokens ||= sum(:input_tokens)

  def output_tokens = @output_tokens ||= sum(:output_tokens)

  def cached_tokens = @cached_tokens ||= sum(:cache_read_tokens)

  def total_tokens = input_tokens + output_tokens

  def context_window = model&.context_window

  def context_used
    @context_used ||= begin
      last = usages.where(status: "succeeded").where.not(input_tokens: nil).reorder(:created_at, :id).last
      last ? last.input_tokens.to_i + last.output_tokens.to_i : 0
    end
  end

  def context_percentage
    return unless context_window&.positive? && context_used.positive?

    ((context_used.to_f / context_window) * 100).clamp(0, 100).round
  end

  def priced? = input_price.present? && output_price.present?

  def cost
    return unless priced? && reported?

    (input_tokens * input_price + output_tokens * output_price) / 1_000_000
  end

  private
    def model = @llm_chat.model

    def usages = @llm_chat.ruby_llm_usages

    def input_price = model&.price(:input)

    def output_price = model&.price(:output)

    def sum(column) = usages.sum(column).to_i
end
