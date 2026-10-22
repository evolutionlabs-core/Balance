class AccountingEngine::Posting
  def self.call(command)
    new(command).call
  end

  def initialize(command)
    @command = command
  end

  def call
    structural = AccountingEngine::Validation::StructureCheck.call(command)
    return AccountingEngine::Receipt.rejected(structural) if structural.any?

    receipt = nil

    JournalEntry.transaction(requires_new: true) do
      command.ledger.lock!
      receipt = recorded_entry ? replay(recorded_entry) : post
      raise ActiveRecord::Rollback unless receipt.success?
    end

    receipt
  end

  private
    attr_reader :command

    def post
      errors = AccountingEngine::Validation.call(command) + AccountingEngine::PeriodState.call(command)
      return AccountingEngine::Receipt.rejected(errors) if errors.any?

      AccountingEngine::Receipt.posted(AccountingEngine::Writer.call(command))
    end

    def recorded_entry
      return unless command.source_type && command.source_id && command.action

      @recorded_entry ||= command.ledger.journal_entries.includes(:journal_entry_lines)
        .find_by(source_type: command.source_type, source_id: command.source_id, action: command.action)
    end

    def replay(entry)
      if entry.effective_date == command.effective_date && signature(entry.journal_entry_lines) == signature(command.lines)
        AccountingEngine::Receipt.replayed(entry)
      else
        AccountingEngine::Receipt.rejected([
          AccountingEngine::Error.new(:duplicate_source, "This #{command.source_type.titleize.downcase} #{command.action} is already recorded as entry ##{entry.number} with different lines")
        ])
      end
    end

    def signature(lines)
      lines.map { |line| [ line.account.id, line.debit, line.credit, line.customer&.id, line.vendor&.id ] }.sort_by(&:to_s)
    end
end
