class Engine::Reversal
  def self.call(entry)
    new(entry).call
  end

  def initialize(entry)
    @entry = entry
  end

  def call
    LedgerEntry.transaction do
      entry.lock!
      errors = guards

      if errors.empty?
        Engine::PostingOrchestrator.call(command)
      else
        Engine::Receipt.new(nil, errors.freeze, :reject, [])
      end
    end
  end

  private
    attr_reader :entry

    def guards
      if entry.reverses_ledger_entry_id
        [ "Cannot reverse an entry that is itself a reversal" ]
      elsif entry.reversals.exists?
        [ "Entry #{entry.id} has already been reversed" ]
      else
        []
      end
    end

    def command
      Engine::Command.new(
        ledger: entry.ledger,
        effective_date: Date.current,
        reverses_ledger_entry: entry,
        lines: entry.ledger_lines.map do |line|
          Engine::Command::Line.new(
            ledger_account: line.ledger_account,
            debit: line.credit,
            credit: line.debit
          )
        end
      )
    end
end
