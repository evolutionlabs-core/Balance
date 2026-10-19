module Accounting::Writer
  # PeriodState locks the ledger earlier in the posting transaction, so the
  # next number cannot be taken by a concurrent posting.
  def self.call(command)
    entry = command.ledger.journal_entries.build(
      number: command.ledger.journal_entries.maximum(:number).to_i + 1,
      effective_date: command.effective_date,
      source_type: command.source_type,
      source_id: command.source_id,
      action: command.action,
      description: command.description,
      reverses_entry: command.reverses_entry,
      posted_by: command.posted_by
    )

    command.lines.each do |line|
      entry.journal_entry_lines.build(
        account: line.account,
        debit: line.debit,
        credit: line.credit
      )
    end

    entry.save!
    Result.new(entry)
  end
end
