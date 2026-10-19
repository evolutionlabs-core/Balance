module Accounting
  module Adapters
    class Bill < Base
      private
        def effective_date
          attributes.fetch(:effective_date)
        end

        def action
          "issue"
        end

        def lines
          expense_cmd_lines = expense_lines.map do |expense|
            Accounting::Command::Line.new(account: expense.fetch(:account), debit: expense.fetch(:amount_kobo), credit: 0)
          end

          expense_cmd_lines + [
            Accounting::Command::Line.new(account: account_for("accounts_payable"), debit: 0, credit: total_kobo, vendor: attributes.fetch(:vendor))
          ]
        end

        def total_kobo
          expense_lines.sum { |expense| expense.fetch(:amount_kobo) }
        end

        def expense_lines
          attributes.fetch(:expense_lines)
        end
    end
  end
end
