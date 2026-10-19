class AccountingEngine::Posting
  def self.call(command)
    new(command).call
  end

  def initialize(command)
    @command = command
  end

  def call
    errors = []
    entry = nil
    warnings = []

    JournalEntry.transaction do
      validation = AccountingEngine::Validation.call(command)

      if validation.ok?
        ruled = AccountingEngine::Rules.call(command)
        warnings = ruled.metadata.fetch("warnings", [])
        errors = AccountingEngine::PeriodState.call(ruled).errors

        if errors.empty?
          entry = AccountingEngine::Writer.call(ruled).entry
        else
          raise ActiveRecord::Rollback
        end
      else
        errors = validation.errors
        raise ActiveRecord::Rollback
      end
    end

    AccountingEngine::Receipt.new(entry, errors.freeze, warnings.freeze)
  rescue AccountingEngine::Errors::BusinessRuleError => error
    AccountingEngine::Receipt.new(nil, [ error.message ].freeze, error.warnings.freeze)
  end

  private
    attr_reader :command
end
