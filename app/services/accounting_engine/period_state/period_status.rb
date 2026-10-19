module AccountingEngine
  module PeriodState
    class PeriodStatus
      def self.call(command)
        return [] unless command.ledger.closed_through?(command.effective_date)

        [ Error.new(:period, "Ledger is closed through #{command.ledger.closed_through.iso8601}") ]
      end
    end
  end
end
