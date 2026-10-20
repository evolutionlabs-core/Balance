module AccountingEngine
  module Builders
    class OpeningBalance < Base
      private
        def effective_date
          Date.current
        end

        def action
          "create"
        end

        def description
          "Opening balance"
        end

        def lines
          [
            AccountingEngine::Command::Line.new(account: account_for("bank"), debit: opening_balance_kobo, credit: 0),
            AccountingEngine::Command::Line.new(account: account_for("opening_balance_equity"), debit: 0, credit: opening_balance_kobo)
          ]
        end

        def opening_balance_kobo
          attributes[:opening_balance_kobo]
        end
    end
  end
end
