module Bills
  module Posting
    extend ActiveSupport::Concern

    def issue!
      posted = Bill.transaction do
        lock!

        unless may_enter?
          errors.add(:base, "Bill cannot be entered from its current state")
          raise ActiveRecord::Rollback
        end

        line_errors = expense_line_errors
        unless line_errors.empty?
          line_errors.each { |error| errors.add(:base, error) }
          raise ActiveRecord::Rollback
        end

        update!(bill_date: bill_date.presence || Date.current)
        enter!

        apply_receipt(post_issue_entry)
      end

      restore_status unless posted
      posted.present?
    end

    def record_payment!(payment_account_id:, paid_on:, amount_kobo:)
      recorded = Bill.transaction do
        lock!
        payments.reset

        if payment_rejected?(amount_kobo)
          raise ActiveRecord::Rollback
        end

        payment_account = workspace.payment_accounts.find_by(id: payment_account_id)
        unless payment_account
          errors.add(:base, "Payment account must be a cash or credit-card account in this workspace")
          raise ActiveRecord::Rollback
        end

        application = payments.build(amount_kobo: amount_kobo, workspace: workspace)
        unless application.save
          application.errors.full_messages.each { |message| errors.add(:base, message) }
          raise ActiveRecord::Rollback
        end

        receipt = post_application(application, payment_account, paid_on)
        apply_receipt(receipt)

        application.update!(journal_entry_id: receipt.entry.id)

        payments.reset
        pay! if may_pay?
        true
      end

      restore_status unless recorded
      recorded.present?
    end

    def void!
      voided = Bill.transaction do
        lock!

        unless may_mark_voided?
          errors.add(:base, "Bill cannot be voided from its current state")
          raise ActiveRecord::Rollback
        end

        if open?
          apply_receipt(post_void_entry)
        end

        mark_voided!
        true
      end

      restore_status unless voided
      voided.present?
    end

    private
      def payment_rejected?(amount_kobo)
        unless open?
          errors.add(:base, "Only an entered bill with a balance can be paid")
          return true
        end

        if balance_due_kobo.zero?
          errors.add(:base, "Bill has no outstanding balance")
          return true
        end

        unless amount_kobo.is_a?(Integer) && amount_kobo.positive?
          errors.add(:base, "Payment amount must be positive")
          return true
        end

        if amount_kobo > balance_due_kobo
          errors.add(:base, "Payment amount must be no more than the balance due")
          return true
        end

        false
      end

      def expense_line_errors
        bill_lines.reject(&:marked_for_destruction?).each_with_index.filter_map do |line, index|
          if line.account.nil?
            "Line #{index + 1}: #{line.description.presence || "item"} has no account"
          elsif !BillLine.eligible_account?(line.account)
            "Line #{index + 1}: account #{line.account.name} is not an expense or asset account"
          elsif line.account.ledger.workspace_id != workspace_id
            "Line #{index + 1}: account #{line.account.name} belongs to another workspace"
          end
        end
      end

      def post_issue_entry
        command = Accounting::Adapters::Bill.call(
          workspace: workspace,
          attributes: {
            effective_date: bill_date,
            vendor: vendor,
            expense_lines: posted_expense_lines
          },
          source_id: id,
          description: "#{display_name} from #{vendor.name}"
        )
        Accounting.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "Bill has already been entered." ])
      end

      def post_application(application, payment_account, paid_on)
        command = Accounting::Adapters::BillPayment.call(
          workspace: workspace,
          attributes: {
            paid_on: paid_on,
            payment_account_id: payment_account.id,
            amount_kobo: application.amount_kobo,
            vendor: vendor
          },
          source_id: application.id,
          description: "Payment to #{vendor.name} for #{display_name.downcase_first}"
        )
        Accounting.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "This payment has already been recorded." ])
      end

      def post_void_entry
        command = Accounting::Adapters::Reversal.call(
          workspace: workspace,
          attributes: {
            source_type: "Bill",
            action: "void",
            effective_date: Date.current,
            entry: issue_entry
          },
          source_id: id,
          description: "#{display_name} voided"
        )
        Accounting.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "Bill has already been voided." ])
      end

      def issue_entry
        workspace.ledger.journal_entries.find_by!(source_type: "Bill", source_id: id, action: "issue")
      end

      def posted_expense_lines
        bill_lines.reject(&:marked_for_destruction?).map do |line|
          { account: line.account, amount_kobo: line.amount_kobo }
        end
      end

      def apply_receipt(receipt)
        return true if receipt.success?

        receipt.errors.each { |error| errors.add(:base, error.to_s) }
        raise ActiveRecord::Rollback
      end

      def reject_receipt(messages)
        Accounting::Receipt.rejected(messages)
      end

      # A rollback restores the database but not the in-memory aasm state; put
      # the loaded truth back so the instance stays honest for the caller.
      def restore_status
        return if status_in_database == status

        self.status = status_in_database
        clear_changes_information
      end
  end
end
