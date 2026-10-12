class Engine::PostingOrchestrator
  def self.call(command)
    new(command).call
  end

  def initialize(command)
    @command = command
  end

  def call
    errors = []
    verdict = :reject
    entry = nil
    warnings = []

    LedgerEntry.transaction do
      validation = Engine::Validation.call(command)

      if validation.ok?
        scoped = validation.command
        rules_result = Engine::Rules.call(scoped)
        warnings = rules_result.command.metadata.fetch("warnings", [])
        period_state = Engine::PeriodState.call(rules_result.command)

        errors = period_state.errors
        verdict = decide(rules_result.verdict, errors)

        if verdict == :allow
          entry = Engine::Writer.call(rules_result.command).entry
        else
          raise ActiveRecord::Rollback
        end
      else
        errors = validation.errors
        raise ActiveRecord::Rollback
      end
    end

    Engine::Receipt.new(entry, errors.freeze, verdict, warnings.freeze)
  rescue Engine::Errors::BusinessRuleError => error
    Engine::Receipt.new(nil, [ error.message ].freeze, :reject, error.warnings.freeze)
  end

  private
    attr_reader :command

    def decide(rule_verdict, errors)
      if errors.any?
        :reject
      elsif rule_verdict == :pause
        :pause
      else
        :allow
      end
    end
end
