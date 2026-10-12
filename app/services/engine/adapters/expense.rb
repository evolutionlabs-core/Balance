module Engine
  module Adapters
    class Expense < Base
      private
        def effective_date
          attributes[:payment_date].to_date
        end

        def action
          "create"
        end

        def lines
          debits = category_lines.map do |line|
            Engine::Command::Line.new(
              ledger_account: ledger_account_for(workspace.accounts.find(line[:account_id]).name),
              debit: kobo(line[:amount]),
              credit: 0
            )
          end

          debits << payment_line(debits.sum(&:debit))
        end

        def category_lines
          attributes[:expense_lines_attributes].values.reject { |line| line[:_destroy] == "1" }
        end

        def payment_line(total_kobo)
          Engine::Command::Line.new(
            ledger_account: ledger_account_for(workspace.accounts.find(attributes[:payment_account_id]).name),
            debit: 0,
            credit: total_kobo
          )
        end
    end
  end
end
