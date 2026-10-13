module Engine
  module Adapters
    class Entry < Base
      private
        def effective_date
          attributes.fetch(:effective_date).to_date
        end

        def action
          attributes.fetch(:action, "create")
        end

        def lines
          attributes.fetch(:lines).map do |line|
            Engine::Command::Line.new(
              ledger_account: ledger.ledger_accounts.find(line.fetch(:ledger_account_id)),
              debit: line.fetch(:debit),
              credit: line.fetch(:credit)
            )
          end
        end
    end
  end
end
