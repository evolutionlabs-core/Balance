module Invoices
  module Posting
    extend ActiveSupport::Concern
    include AccountingEngine::Postable

    def issue!
      posted = Invoice.transaction do
        lock!

        unless may_send_to_client?
          errors.add(:base, "Invoice cannot be sent from its current state")
          raise ActiveRecord::Rollback
        end

        line_errors = income_line_errors
        unless line_errors.empty?
          line_errors.each { |error| errors.add(:base, error) }
          raise ActiveRecord::Rollback
        end

        raise ActiveRecord::Rollback unless update(issue_date: issue_date.presence || Date.current)
        send_to_client!

        post_issue_entry
      end

      restore_status unless posted
      posted.present?
    end

    def mark_paid!
      if workspace.default_deposit_account
        record_payment!(deposit_account_id: workspace.default_deposit_account_id, received_on: Date.current, amount_kobo: balance_due_kobo)
      else
        errors.add(:base, "Choose a default deposit account in company settings before marking invoices as paid")
        false
      end
    end

    def record_payment!(deposit_account_id:, received_on:, amount_kobo:)
      recorded = Invoice.transaction do
        lock!
        payments.reset

        if payment_rejected?(amount_kobo, received_on)
          raise ActiveRecord::Rollback
        end

        deposit_account = workspace.deposit_accounts.find_by(id: deposit_account_id)
        unless deposit_account
          errors.add(:base, "Deposit account must be a bank or cash account in this workspace")
          raise ActiveRecord::Rollback
        end

        application = payments.build(amount_kobo: amount_kobo, workspace: workspace)
        unless application.save
          application.errors.full_messages.each { |message| errors.add(:base, message) }
          raise ActiveRecord::Rollback
        end

        entry = post_application(application, deposit_account, received_on)
        application.update!(journal_entry_id: entry.id)

        payments.reset
        pay! if may_pay?
        true
      end

      restore_status unless recorded
      recorded.present?
    end

    def reverse_payment!(payment)
      reversed = Invoice.transaction do
        lock!

        if payment.reverses_invoice_payment_id? || payment.reversal_payment.present?
          errors.add(:base, "This payment has already been reversed")
          raise ActiveRecord::Rollback
        end

        reversal = payments.build(workspace: workspace, amount_kobo: payment.amount_kobo, reverses_invoice_payment: payment)
        unless reversal.save
          reversal.errors.full_messages.each { |message| errors.add(:base, message) }
          raise ActiveRecord::Rollback
        end

        entry = reverse_in_ledger!(payment.journal_entry, on: Date.current, source_type: "InvoicePayment", source_id: reversal.id,
          description: "Payment reversed for invoice #{invoice_number}")
        reversal.update!(journal_entry_id: entry.id)

        payments.reset
        reopen! if may_reopen?
        true
      end

      restore_status unless reversed
      reversed.present?
    end

    def void!
      voided = Invoice.transaction do
        lock!

        unless may_mark_voided?
          errors.add(:base, "Invoice cannot be voided from its current state")
          raise ActiveRecord::Rollback
        end

        if sent?
          post_void_entry
        end

        mark_voided!
        true
      end

      restore_status unless voided
      voided.present?
    end

    private
      def payment_rejected?(amount_kobo, received_on)
        unless sent?
          errors.add(:base, "Only a sent invoice with a balance can receive payment")
          return true
        end

        if balance_due_kobo.zero?
          errors.add(:base, "Invoice has no outstanding balance")
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

        if received_on.nil?
          errors.add(:base, "Payment date is required")
        elsif received_on > Date.current
          errors.add(:base, "Payment date can't be in the future")
        elsif received_on < issue_date
          errors.add(:base, "Payment date can't be before the invoice date")
        else
          return false
        end

        true
      end

      def income_line_errors
        invoice_lines.reject(&:marked_for_destruction?).each_with_index.filter_map do |line, index|
          if line.account.nil?
            "Line #{index + 1}: #{line.description.presence || "item"} has no income account"
          elsif line.account.base_type != "income"
            "Line #{index + 1}: account #{line.account.name} is not an income account"
          elsif line.account.ledger.workspace_id != workspace_id
            "Line #{index + 1}: account #{line.account.name} belongs to another workspace"
          end
        end
      end

      def post_issue_entry
        record_in_ledger!(
          AccountingEngine::Builders::Invoice,
          attributes: {
            effective_date: issue_date,
            customer: customer,
            income_lines: posted_income_lines
          },
          source_id: id,
          description: "Invoice #{invoice_number}"
        )
      end

      def post_application(application, deposit_account, received_on)
        record_in_ledger!(
          AccountingEngine::Builders::InvoicePayment,
          attributes: {
            received_on: received_on,
            deposit_account_id: deposit_account.id,
            amount_kobo: application.amount_kobo,
            customer: customer
          },
          source_id: application.id,
          description: "Payment received for invoice #{invoice_number}"
        )
      end

      def post_void_entry
        entry = issue_entry
        unless entry
          errors.add(:base, "This invoice has no recorded entry to reverse")
          raise ActiveRecord::Rollback
        end

        reverse_in_ledger!(entry, on: Date.current, source_type: "Invoice", source_id: id, action: "void",
          description: "Invoice #{invoice_number} voided")
      end

      def issue_entry
        workspace.ledger.journal_entries.find_by(source_type: "Invoice", source_id: id, action: "issue")
      end

      def posted_income_lines
        invoice_lines.reject(&:marked_for_destruction?).map do |line|
          { account: line.account, amount_kobo: line.amount_minor }
        end
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
