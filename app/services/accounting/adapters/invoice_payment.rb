module Accounting
  module Adapters
    class InvoicePayment < Base
      private
        def effective_date
          attributes.fetch(:received_on)
        end

        def action
          "apply"
        end

        def lines
          [
            Accounting::Command::Line.new(account: payment_account, debit: amount, credit: 0),
            Accounting::Command::Line.new(account: account_for("accounts_receivable"), debit: 0, credit: amount, customer: attributes.fetch(:customer))
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
