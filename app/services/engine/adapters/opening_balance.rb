module Engine
  module Adapters
    class OpeningBalance < Base
      BANK_CODE = "1020"
      EQUITY_NAME = "Opening Balance Equity"

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
          bank = ledger.ledger_accounts.find_by!(code: BANK_CODE)
          equity = ledger_account_for(EQUITY_NAME)

          [
            Engine::Command::Line.new(ledger_account: bank, debit: opening_balance_kobo, credit: 0),
            Engine::Command::Line.new(ledger_account: equity, debit: 0, credit: opening_balance_kobo)
          ]
        end

        def opening_balance_kobo
          attributes[:opening_balance_kobo]
        end
    end
  end
end
