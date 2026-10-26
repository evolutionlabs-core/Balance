module AccountingEngine
  module Builders
    class CreditNote < Base
      private
        def effective_date
          attributes.fetch(:issued_on)
        end

        def action
          "issue"
        end

        def lines
          income_cmd_lines = income_lines.map do |income|
            AccountingEngine::Command::Line.new(account: income.fetch(:account), debit: income.fetch(:amount_kobo), credit: 0)
          end

          income_cmd_lines + [
            AccountingEngine::Command::Line.new(account: account_for("accounts_receivable"), debit: 0, credit: total_kobo, customer: attributes.fetch(:customer))
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
