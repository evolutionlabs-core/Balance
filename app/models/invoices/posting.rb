module Invoices
  module Posting
    extend ActiveSupport::Concern

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

        update!(issue_date: issue_date.presence || Date.current)
        send_to_client!

        apply_receipt(post_issue_entry, pause_message: "This invoice requires approval before it can be sent.")
      end

      restore_status unless posted
      posted.present?
    end

    def record_payment!(payment_ledger_account_id:, received_on:, amount_kobo:)
      recorded = Invoice.transaction do
        lock!
        payments.reset

        if payment_rejected?(amount_kobo)
          raise ActiveRecord::Rollback
        end

        payment_ledger_account = workspace.payment_accounts.find_by(id: payment_ledger_account_id)
        unless payment_ledger_account
          errors.add(:base, "Payment account must be a cash or credit-card account in this workspace")
          raise ActiveRecord::Rollback
        end

        application = payments.build(amount_kobo: amount_kobo, workspace: workspace)
        unless application.save
          application.errors.full_messages.each { |message| errors.add(:base, message) }
          raise ActiveRecord::Rollback
        end

        receipt = post_application(application, payment_ledger_account, received_on)
        apply_receipt(receipt, pause_message: "This payment requires approval before it can be recorded.")

        application.update!(ledger_entry_id: receipt.entry.id)

        payments.reset
        pay! if may_pay?
        true
      end

      restore_status unless recorded
      recorded.present?
    end

    def void!
      voided = Invoice.transaction do
        lock!

        unless may_mark_voided?
          errors.add(:base, "Invoice cannot be voided from its current state")
          raise ActiveRecord::Rollback
        end

        if sent?
          apply_receipt(post_void_entry, pause_message: "This invoice requires approval before it can be voided.")
        end

        mark_voided!
        true
      end

      restore_status unless voided
      voided.present?
    end

    private
      def payment_rejected?(amount_kobo)
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

        false
      end

      def income_line_errors
        invoice_lines.reject(&:marked_for_destruction?).each_with_index.filter_map do |line, index|
          if line.ledger_account.nil?
            "Line #{index + 1}: #{line.description.presence || "item"} has no income account"
          elsif line.ledger_account.base_type != "income"
            "Line #{index + 1}: account #{line.ledger_account.name} is not an income account"
          elsif line.ledger_account.ledger.workspace_id != workspace_id
            "Line #{index + 1}: account #{line.ledger_account.name} belongs to another workspace"
          end
        end
      end

      def post_issue_entry
        command = Engine::Adapters::Invoice.call(
          workspace: workspace,
          attributes: {
            action: "issue",
            effective_date: issue_date,
            income_lines: posted_income_lines
          },
          source_id: id,
          description: "Invoice #{invoice_number}"
        )
        Engine.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "Invoice has already been sent." ])
      end

      def post_application(application, payment_ledger_account, received_on)
        command = Engine::Adapters::InvoicePayment.call(
          workspace: workspace,
          attributes: {
            received_on: received_on,
            payment_ledger_account_id: payment_ledger_account.id,
            amount_kobo: application.amount_kobo
          },
          source_id: application.id,
          description: "Payment received for invoice #{invoice_number}"
        )
        Engine.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "This payment has already been recorded." ])
      end

      def post_void_entry
        command = Engine::Adapters::Invoice.call(
          workspace: workspace,
          attributes: {
            action: "void",
            effective_date: Date.current,
            income_lines: posted_income_lines
          },
          source_id: id,
          description: "Invoice #{invoice_number} voided"
        )
        Engine.post(command)
      rescue ActiveRecord::RecordNotFound => error
        reject_receipt([ error.message ])
      rescue ActiveRecord::RecordNotUnique
        reject_receipt([ "Invoice has already been voided." ])
      end

      def posted_income_lines
        invoice_lines.reject(&:marked_for_destruction?).map do |line|
          { ledger_account: line.ledger_account, amount_kobo: line.amount_minor }
        end
      end

      def apply_receipt(receipt, pause_message:)
        return true if receipt.success? && receipt.verdict == :allow

        receipt.errors.each { |error| errors.add(:base, error.to_s) }
        errors.add(:base, pause_message) if receipt.verdict == :pause
        raise ActiveRecord::Rollback
      end

      def reject_receipt(messages)
        Engine::Receipt.new(nil, messages.freeze, :reject, [].freeze)
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
