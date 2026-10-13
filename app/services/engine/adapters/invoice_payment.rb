module Engine
  module Adapters
    class InvoicePayment < Base
      private
        def effective_date
          attributes.fetch(:received_on)
        end

        def action
          attributes.fetch(:action, "apply")
        end

        def lines
          if action == "reverse"
            [
              Engine::Command::Line.new(ledger_account: receivable_account, debit: amount, credit: 0),
              Engine::Command::Line.new(ledger_account: payment_ledger_account, debit: 0, credit: amount)
            ]
          else
            [
              Engine::Command::Line.new(ledger_account: payment_ledger_account, debit: amount, credit: 0),
              Engine::Command::Line.new(ledger_account: receivable_account, debit: 0, credit: amount)
            ]
          end
        end

        def payment_ledger_account
          ledger.ledger_accounts.find(attributes.fetch(:payment_ledger_account_id))
        end

        def amount
          attributes.fetch(:amount_kobo)
        end
    end
  end
end
