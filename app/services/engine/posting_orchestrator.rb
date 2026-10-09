class Engine::PostingOrchestrator
  def self.call(command, rules: [])
    new(command, rules).call
  end

  def initialize(command, rules)
    @command = command
    @rules = rules
  end

  def call
    errors = []
    verdict = :reject
    entry = nil

    LedgerEntry.transaction do
      validation = Engine::Validation.call(command)
      rules_result = Engine::Rules.call(command, rules: rules)
      period_state = Engine::PeriodState.call(command)

      errors = validation.errors + rules_result.errors + period_state.errors
      verdict = decide(rules_result.verdict, errors)

      if verdict == :allow
        entry = Engine::Writer.call(command)
      else
        raise ActiveRecord::Rollback
      end
    end

    Engine::Receipt.new(entry, errors.freeze, verdict)
  end

  private
    attr_reader :command, :rules

    # Any failure wins over pause, and pause wins over allow. The rules
    # verdict is honoured even when a rule rejects without a message.
    def decide(rule_verdict, errors)
      if errors.any? || rule_verdict == :reject
        :reject
      elsif rule_verdict == :pause
        :pause
      else
        :allow
      end
    end
end
