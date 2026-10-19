module AccountingEngine
  module Query
    class SnapshotGuard
      def self.validate!(ledger_id:, as_of_date:)
        raise ArgumentError, "Ledger #{ledger_id} not found" unless Ledger.exists?(id: ledger_id)
        raise ArgumentError, "Cannot query future date" if as_of_date > Date.current
      end
    end
  end
end
