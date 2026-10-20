module AccountingEngine
  module Postable
    extend ActiveSupport::Concern

    private
      def record_in_ledger!(builder, **arguments)
        entry_or_rollback!(AccountingEngine.record(builder, workspace: workspace, **arguments))
      end

      def reverse_in_ledger!(entry, **arguments)
        entry_or_rollback!(AccountingEngine.reverse(entry, **arguments))
      end

      def entry_or_rollback!(receipt)
        if receipt.success?
          receipt.entry
        else
          receipt.errors.each { |error| errors.add(:base, error.to_s) }
          raise ActiveRecord::Rollback
        end
      end
  end
end
