module Engine
  module Adapters
    class Invoice < Base
      private
        def effective_date
          attributes.fetch(:effective_date)
        end

        def action
          attributes.fetch(:action, "issue")
        end

        def lines
          receivable = receivable_account

          income_cmd_lines = income_lines.map do |income|
            Engine::Command::Line.new(
              ledger_account: income.fetch(:ledger_account),
              debit: action == "issue" ? 0 : income.fetch(:amount_kobo),
              credit: action == "issue" ? income.fetch(:amount_kobo) : 0
            )
          end

          income_cmd_lines + [
            Engine::Command::Line.new(
              ledger_account: receivable,
              debit: action == "issue" ? total_kobo : 0,
              credit: action == "issue" ? 0 : total_kobo
            )
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
