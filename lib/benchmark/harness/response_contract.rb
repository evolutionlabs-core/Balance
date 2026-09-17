class Llm::Harness::ResponseContract
  attr_reader :errors

  def initialize(response:, contract:)
    # Models differ in typographic output (’ vs ', — vs -); normalise so the
    # same behaviour matches the same contract regardless of encoding choices.
    @response = normalise(response)
    @contract = contract || {}
    @errors = validate
  end

  def valid? = errors.empty?

  private

  attr_reader :response, :contract

  def normalise(value)
    value.to_s
      .tr("\u{2018}\u{2019}\u{201C}\u{201D}", "''\"\"")
      .tr("\u{2013}\u{2014}", "--")
      .strip
  end

  def validate
    [].tap do |messages|
      validate_required_patterns(messages)
      validate_forbidden_patterns(messages)
      validate_question_count(messages)
      validate_question_only(messages) if contract["question_only"]
    end
  end

  def validate_required_patterns(messages)
    Array(contract["required_patterns"]).each do |pattern|
      messages << "must match /#{pattern}/" unless response.match?(regexp(pattern))
    end
  end

  def validate_forbidden_patterns(messages)
    Array(contract["forbidden_patterns"]).each do |pattern|
      messages << "must not match /#{pattern}/" if response.match?(regexp(pattern))
    end
  end

  def validate_question_count(messages)
    return unless contract.key?("question_count")

    expected = contract.fetch("question_count")
    actual = response.scan(/\?+/).size
    messages << "must contain exactly #{expected} question(s), found #{actual}" unless actual == expected
  end

  def validate_question_only(messages)
    messages << "must contain only one question" unless response.end_with?("?")
    messages << "must not contain a preamble or second sentence" if response.match?(/[.!]\s+\S/)
    list_pattern = /(?:\A|\n|[.!?]\s+)\s*(?:[-*]|\d+[.)])\s+/
    messages << "must not use a list for one clarification" if response.match?(list_pattern)
  end

  def regexp(pattern)
    Regexp.new(pattern, Regexp::IGNORECASE)
  end
end
