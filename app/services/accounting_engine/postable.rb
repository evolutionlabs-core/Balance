module AccountingEngine
  module Postable
    extend ActiveSupport::Concern

    private
      def record_in_ledger!(builder, **arguments)
        receipt = AccountingEngine.record(builder, workspace: workspace, **arguments)

        if receipt.success?
          receipt.entry
        else
          receipt.errors.each { |error| errors.add(:base, error.to_s) }
          raise ActiveRecord::Rollback
        end
      end
  end
end
