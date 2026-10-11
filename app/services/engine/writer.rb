module Engine::Writer
  def self.call(command)
    entry = command.ledger.ledger_entries.build(
      effective_date: command.effective_date,
      source_type: command.source_type,
      source_id: command.source_id,
      action: command.action
    )

    command.lines.each do |line|
      entry.ledger_lines.build(
        ledger_account: line.ledger_account,
        debit: line.debit,
        credit: line.credit
      )
    end

    entry.save!
    Result.new(entry)
  end
end
