module CreditNotes
  module Posting
    extend ActiveSupport::Concern
    include AccountingEngine::Postable
    include IncomeLineChecks

    def issue!
      issued = CreditNote.transaction do
        raise ActiveRecord::Rollback unless save

        line_errors = income_line_errors(lines.to_a)
        unless line_errors.empty?
          line_errors.each { |error| errors.add(:base, error) }
          raise ActiveRecord::Rollback
        end

        entry = post_issue_entry
        update!(journal_entry_id: entry.id)
        apply_to_invoices
        true
      end

      issued.present?
    end

    def void!
      voided = CreditNote.transaction do
        lock!

        if voided?
          errors.add(:base, "This credit note has already been voided")
          raise ActiveRecord::Rollback
        end

        entry = reverse_in_ledger!(journal_entry, on: Date.current, source_type: "CreditNote", source_id: id, action: "void",
          description: "Credit note #{number} voided")
        credited_invoices = applications.map(&:invoice)
        applications.each(&:destroy!)
        update!(voided_at: Time.current, void_journal_entry_id: entry.id)
        credited_invoices.each { |credited| credited.reopen! if credited.reload.may_reopen? }
        true
      end

      voided.present?
    end

    private
      def post_issue_entry
        record_in_ledger!(
          AccountingEngine::Builders::CreditNote,
          attributes: {
            issued_on: issued_on,
            customer: customer,
            income_lines: discounted_income_lines(lines.map { |line| { account: line.account, amount_kobo: line.amount_minor } })
          },
          source_id: id,
          description: "Credit note #{number}"
        )
      end

      def apply_to_invoices
        targets = invoice ? [ invoice ] : customer.invoices.outstanding.order(:issue_date, :id)

        targets.each do |target|
          applications.reset
          break if unapplied_minor.zero?

          target.apply_credit(self)
        end
      end
  end
end
