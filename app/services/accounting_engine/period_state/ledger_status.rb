module AccountingEngine
  module PeriodState
    class LedgerStatus
      def self.call(command)
        if command.ledger.active?
          []
        else
          [ AccountingEngine::Error.new(:ledger, "Ledger #{command.ledger.name} is #{command.ledger.status}") ]
        end
      end
    end
  end
end
