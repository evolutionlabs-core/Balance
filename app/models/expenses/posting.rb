module Expenses
  module Posting
    extend ActiveSupport::Concern

    def record_entry!
      recorded = false
      Expense.transaction do
        next unless save

        apply_receipt(post_to_engine, pause_message: "This expense requires approval before it can be recorded.")

        mark_posted!
        recorded = true
      end

      recorded
    end

    private
      def post_to_engine
        command = Engine::Adapters::Expense.call(
          workspace: workspace,
          attributes: posting_attributes,
          source_id: id,
          description: description
        )
        Engine.post(command)
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

      def apply_receipt(receipt, pause_message:)
        return true if receipt.success? && receipt.verdict == :allow

        receipt.errors.each { |error| errors.add(:base, error.to_s) }
        errors.add(:base, pause_message) if receipt.verdict == :pause
        raise ActiveRecord::Rollback
      end

      def receipt(errors)
        Engine::Receipt.new(nil, errors.freeze, :reject, [].freeze)
      end
  end
end
