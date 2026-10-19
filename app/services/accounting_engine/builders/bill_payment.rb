module AccountingEngine
  module Builders
    class BillPayment < Base
      private
        def effective_date
          attributes.fetch(:paid_on)
        end

        def action
          "apply"
        end

        def lines
          [
            AccountingEngine::Command::Line.new(account: account_for("accounts_payable"), debit: amount, credit: 0, vendor: attributes.fetch(:vendor)),
            AccountingEngine::Command::Line.new(account: payment_account, debit: 0, credit: amount)
          ]
        end

        def payment_account
          ledger.accounts.find(attributes.fetch(:payment_account_id))
        end

        def amount
          attributes.fetch(:amount_kobo)
        end
    end
  end
end
