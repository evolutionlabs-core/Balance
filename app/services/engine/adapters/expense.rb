module Engine
  module Adapters
    class Expense < Base
      private
        def effective_date
          attributes[:payment_date]
        end

        def action
          "create"
        end

        def lines
          debits = expense_lines.map do |line|
            Engine::Command::Line.new(
              ledger_account: ledger_account(line.fetch(:account_id)),
              debit: line.fetch(:amount_kobo),
              credit: 0
            )
          end

          debits << payment_line(debits.sum(&:debit))
        end

        def expense_lines
          attributes.fetch(:expense_lines)
        end

        def payment_line(total_kobo)
          Engine::Command::Line.new(
            ledger_account: ledger_account(attributes.fetch(:payment_account_id)),
            debit: 0,
            credit: total_kobo
          )
        end

        def ledger_account(id)
          ledger.ledger_accounts.find(id)
        end
    end
  end
end
