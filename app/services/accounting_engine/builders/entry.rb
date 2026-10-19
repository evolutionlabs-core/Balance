module AccountingEngine
  module Builders
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
            AccountingEngine::Command::Line.new(
              account: ledger.accounts.find(line.fetch(:account_id)),
              debit: line.fetch(:debit),
              credit: line.fetch(:credit)
            )
          end
        end
    end
  end
end
