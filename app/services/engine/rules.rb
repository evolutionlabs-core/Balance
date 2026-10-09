class Engine::Rules
  Result = Data.define(:verdict, :errors) do
    def allow? = verdict == :allow
  end

  # Rules will be scoped, persisted records evaluated here. Until then the
  # registry is empty and every command is allowed through to the writer.
  def self.call(command, rules: [])
    new(command, rules).call
  end

  def initialize(command, rules)
    @command = command
    @rules = rules
  end

  def call
    verdicts = applicable_rules.map { |rule| rule.evaluate(command) }
    errors = verdicts.flat_map(&:errors)

    Result.new(verdict_for(verdicts, errors), errors.freeze)
  end

  private
    attr_reader :command, :rules

    def applicable_rules
      rules.select { |rule| rule.applies_to?(command) }
    end

    def verdict_for(verdicts, errors)
      if errors.any? || verdicts.any? { |verdict| verdict.verdict == :reject }
        :reject
      elsif verdicts.any? { |verdict| verdict.verdict == :pause }
        :pause
      else
        :allow
      end
    end
end
