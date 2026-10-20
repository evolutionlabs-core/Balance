module AccountingEngine::Validation
  module ReversalCheck
    def self.call(command)
      original = command.reverses_entry

      if original.nil?
        []
      elsif original.ledger_id != command.ledger.id
        [ error("The reversed entry belongs to another ledger") ]
      elsif original.reverses_entry_id?
        [ error("Entry ##{original.number} is itself a reversal") ]
      elsif JournalEntry.exists?(reverses_entry_id: original.id)
        [ error("Entry ##{original.number} has already been reversed") ]
      elsif mirrored(original) != signature(command.lines)
        [ error("A reversal must mirror every line of entry ##{original.number}") ]
      else
        []
      end
    end

    class << self
      private
        def mirrored(entry)
          entry.journal_entry_lines.map { |line| [ line.account_id, line.credit, line.debit, line.customer_id.to_i, line.vendor_id.to_i ] }.sort
        end

        def signature(lines)
          lines.map { |line| [ line.account.id, line.debit, line.credit, line.customer&.id.to_i, line.vendor&.id.to_i ] }.sort
        end

        def error(message)
          AccountingEngine::Error.new(:reversal, message)
        end
    end
  end
end
