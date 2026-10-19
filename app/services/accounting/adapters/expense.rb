module Accounting
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
            Accounting::Command::Line.new(
              account: account(line.fetch(:account_id)),
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
          Accounting::Command::Line.new(
            account: account(attributes.fetch(:payment_account_id)),
            debit: 0,
            credit: total_kobo
          )
        end

        def account(id)
          ledger.accounts.find(id)
        end
    end
  end
end
