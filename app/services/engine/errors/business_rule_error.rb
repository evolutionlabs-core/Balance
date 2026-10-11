class Engine::Errors::BusinessRuleError < StandardError
  attr_reader :rule, :warnings

  def initialize(rule:, warnings: [])
    @rule = rule
    @warnings = Array(warnings).dup.freeze
    super(rule.message)
  end
end
