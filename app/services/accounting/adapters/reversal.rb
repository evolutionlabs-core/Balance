module Accounting
  module Adapters
    # Mirrors a posted entry line for line. The caller names the source and
    # action of the business event that reverses it, such as an invoice void.
    class Reversal < Base
      private
        def source_type
          attributes.fetch(:source_type)
        end

        def effective_date
          attributes.fetch(:effective_date).to_date
        end

        def action
          attributes.fetch(:action, "reverse")
        end

        def reverses_entry
          attributes.fetch(:entry)
        end

        def lines
          reverses_entry.journal_entry_lines.map do |line|
            Accounting::Command::Line.new(account: line.account, debit: line.credit, credit: line.debit)
          end
        end
    end
  end
end
