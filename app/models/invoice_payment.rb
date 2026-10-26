class InvoicePayment < ApplicationRecord
  belongs_to :workspace
  belongs_to :invoice
  belongs_to :journal_entry, optional: true
  belongs_to :reverses_invoice_payment, class_name: "InvoicePayment", optional: true
  has_one :reversal_payment,
    class_name: "InvoicePayment",
    foreign_key: :reverses_invoice_payment_id,
    dependent: :restrict_with_error

  validates :amount_kobo, numericality: { only_integer: true, greater_than: 0 }
  validates :invoice_id, uniqueness: { scope: :journal_entry_id }
  validates :reverses_invoice_payment_id, uniqueness: true, allow_nil: true
  validate :records_belong_to_workspace
  validate :invoice_is_payable
  validate :amount_does_not_exceed_balance
  validate :reversal_matches_original

  before_update { throw(:abort) unless stamping_journal_entry? }
  before_destroy { throw(:abort) }

  # A reversal settles the same invoice in the opposite direction, so it
  # returns money to the balance instead of consuming it.
  def effective_amount_kobo
    reverses_invoice_payment_id? ? -amount_kobo : amount_kobo
  end

  private
    def stamping_journal_entry?
      journal_entry_id_changed? && journal_entry_id.present? &&
        (changes.keys - %w[journal_entry_id updated_at]).empty?
    end

    def records_belong_to_workspace
      return if workspace.blank?

      errors.add(:invoice, "must belong to the workspace") if invoice && invoice.workspace_id != workspace_id
      errors.add(:journal_entry, "must belong to the workspace") if journal_entry&.ledger && journal_entry.ledger.workspace_id != workspace_id
    end

    def invoice_is_payable
      return if invoice.blank? || invoice.sent? || invoice.paid?

      errors.add(:invoice, "must be sent before payment can be applied")
    end

    def amount_does_not_exceed_balance
      return if invoice.blank? || amount_kobo.blank? || reverses_invoice_payment.present?

      applied_without_self = invoice.payments.reject { |payment| payment == self }
        .sum(&:effective_amount_kobo)

      return if amount_kobo <= invoice.total_minor - invoice.credited_amount_minor - applied_without_self

      errors.add(:amount_kobo, "cannot exceed the invoice balance")
    end

    def reversal_matches_original
      return if reverses_invoice_payment.blank?

      original = reverses_invoice_payment
      errors.add(:reverses_invoice_payment, "must belong to the workspace") if original.workspace_id != workspace_id
      errors.add(:invoice, "must match the original payment") if original.invoice_id != invoice_id
      errors.add(:amount_kobo, "must match the original payment") if original.amount_kobo != amount_kobo
    end
end
