module Expenses
  module Posting
    extend ActiveSupport::Concern
    include AccountingEngine::Postable

    def record_entry!
      recorded = false
      Expense.transaction do
        next unless save

        record_in_ledger!(AccountingEngine::Builders::Expense, attributes: posting_attributes, source_id: id, description: description)

        mark_posted!
        recorded = true
      end

      recorded
    end

    private
      def posting_attributes
        {
          payment_date: payment_date,
          payment_account_id: payment_account_id,
          expense_lines: expense_lines.reject(&:marked_for_destruction?).map do |line|
            { account_id: line.account_id, amount_kobo: line.amount_kobo }
          end
        }
      end
  end
end
