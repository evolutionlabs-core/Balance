module AccountingEngine
  module Builders
    class Invoice < Base
      private
        def effective_date
          attributes.fetch(:effective_date)
        end

        def action
          "issue"
        end

        def lines
          income_cmd_lines = income_lines.map do |income|
            AccountingEngine::Command::Line.new(account: income.fetch(:account), debit: 0, credit: income.fetch(:amount_kobo))
          end

          income_cmd_lines + [
            AccountingEngine::Command::Line.new(account: account_for("accounts_receivable"), debit: total_kobo, credit: 0, customer: attributes.fetch(:customer))
          ]
        end

        def total_kobo
          income_lines.sum { |income| income.fetch(:amount_kobo) }
        end

        def income_lines
          attributes.fetch(:income_lines)
        end
    end
  end
end
