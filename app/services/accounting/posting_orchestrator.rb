class Accounting::PostingOrchestrator
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
      validation = Accounting::Validation.call(command)

      if validation.ok?
        ruled = Accounting::Rules.call(command)
        warnings = ruled.metadata.fetch("warnings", [])
        errors = Accounting::PeriodState.call(ruled).errors

        if errors.empty?
          entry = Accounting::Writer.call(ruled).entry
        else
          raise ActiveRecord::Rollback
        end
      else
        errors = validation.errors
        raise ActiveRecord::Rollback
      end
    end

    Accounting::Receipt.new(entry, errors.freeze, warnings.freeze)
  rescue Accounting::Errors::BusinessRuleError => error
    Accounting::Receipt.new(nil, [ error.message ].freeze, error.warnings.freeze)
  end

  private
    attr_reader :command
end
