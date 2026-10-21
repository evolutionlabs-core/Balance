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

    def void!
      voided = false
      Expense.transaction do
        reverse_in_ledger!(journal_entry, on: Date.current, source_type: "Expense", source_id: id, action: "void",
          description: "Voided expense: #{description}")

        update!(status: :voided)
        voided = true
      end

      restore_status unless voided
      voided
    end

    private
      def restore_status
        self.status = status_in_database
        clear_changes_information
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
  end
end
