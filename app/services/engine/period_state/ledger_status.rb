module Engine
  module PeriodState
    class LedgerStatus
      def self.call(command)
        if command.ledger.active?
          []
        else
          [ Error.new(:period, "Ledger #{command.ledger.name} is #{command.ledger.status}") ]
        end
      end
    end
  end
end
