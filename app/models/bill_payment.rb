class BillPayment < ApplicationRecord
  belongs_to :workspace
  belongs_to :bill
  belongs_to :journal_entry, optional: true
  belongs_to :reverses_bill_payment, class_name: "BillPayment", optional: true
  has_one :reversal_payment,
    class_name: "BillPayment",
    foreign_key: :reverses_bill_payment_id,
    dependent: :restrict_with_error

  validates :amount_kobo, numericality: { only_integer: true, greater_than: 0 }
  validates :bill_id, uniqueness: { scope: :journal_entry_id }
  validates :reverses_bill_payment_id, uniqueness: true, allow_nil: true
  validate :records_belong_to_workspace
  validate :bill_is_payable
  validate :amount_does_not_exceed_balance
  validate :reversal_matches_original

  before_update { throw(:abort) unless stamping_journal_entry? }
  before_destroy { throw(:abort) }

  # A reversal settles the same bill in the opposite direction, so it returns
  # money to the balance owed instead of consuming it.
  def effective_amount_kobo
    reverses_bill_payment_id? ? -amount_kobo : amount_kobo
  end

  private
    def stamping_journal_entry?
      journal_entry_id_changed? && journal_entry_id.present? &&
        (changes.keys - %w[journal_entry_id updated_at]).empty?
    end

    def records_belong_to_workspace
      return if workspace.blank?

      errors.add(:bill, "must belong to the workspace") if bill && bill.workspace_id != workspace_id
      errors.add(:journal_entry, "must belong to the workspace") if journal_entry&.ledger && journal_entry.ledger.workspace_id != workspace_id
    end

    def bill_is_payable
      return if bill.blank? || bill.open? || bill.paid?

      errors.add(:bill, "must be entered before payment can be applied")
    end

    def amount_does_not_exceed_balance
      return if bill.blank? || amount_kobo.blank? || reverses_bill_payment.present?

      applied_without_self = bill.payments.reject { |payment| payment == self }
        .sum(&:effective_amount_kobo)

      return if amount_kobo <= bill.total_kobo - applied_without_self

      errors.add(:amount_kobo, "cannot exceed the bill balance")
    end

    def reversal_matches_original
      return if reverses_bill_payment.blank?

      original = reverses_bill_payment
      errors.add(:reverses_bill_payment, "must belong to the workspace") if original.workspace_id != workspace_id
      errors.add(:bill, "must match the original payment") if original.bill_id != bill_id
      errors.add(:amount_kobo, "must match the original payment") if original.amount_kobo != amount_kobo
    end
end
