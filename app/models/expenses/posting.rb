module Expenses
  module Posting
    extend ActiveSupport::Concern

    def record_entry!
      recorded = false
      Expense.transaction do
        next unless save

        apply_receipt(post_to_engine)

        mark_posted!
        recorded = true
      end

      recorded
    end

    private
      def post_to_engine
        command = AccountingEngine::Builders::Expense.call(
          workspace: workspace,
          attributes: posting_attributes,
          source_id: id,
          description: description
        )
        AccountingEngine.post(command)
      rescue ActiveRecord::RecordNotFound => error
        receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        receipt([ "Expense has already been recorded." ])
      end

      def posting_attributes
        {
          payment_date: payment_date,
          payment_account_id: payment_account_id,
          expense_lines: expense_lines.reject(&:marked_for_destruction?).map do |line|
            { account_id: line.account_id, amount_kobo: line.amount_kobo }
          end
        }
      end

      def apply_receipt(receipt)
        return true if receipt.success?

        receipt.errors.each { |error| errors.add(:base, error.to_s) }
        raise ActiveRecord::Rollback
      end

      def receipt(errors)
        AccountingEngine::Receipt.rejected(errors)
      end
  end
end
