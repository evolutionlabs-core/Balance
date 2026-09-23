class ReceivableApplication < ApplicationRecord
  belongs_to :workspace
  belongs_to :invoice
  belongs_to :journal_entry
  belongs_to :reverses_receivable_application, class_name: "ReceivableApplication", optional: true
  has_one :reversal_application,
    class_name: "ReceivableApplication",
    foreign_key: :reverses_receivable_application_id,
    dependent: :restrict_with_error

  validates :amount_kobo, numericality: { only_integer: true, greater_than: 0 }
  validates :invoice_id, uniqueness: { scope: :journal_entry_id }
  validates :reverses_receivable_application_id, uniqueness: true, allow_nil: true
  validate :records_belong_to_workspace
  validate :invoice_is_posted
  validate :amount_does_not_exceed_balance
  validate :journal_entry_matches_customer
  validate :reversal_matches_original

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def effective_amount_kobo
    reverses_receivable_application_id? ? -amount_kobo : amount_kobo
  end

  private
    def records_belong_to_workspace
      return if workspace.blank?

      errors.add(:invoice, "must belong to the workspace") if invoice && invoice.workspace_id != workspace_id
      errors.add(:journal_entry, "must belong to the workspace") if journal_entry && journal_entry.workspace_id != workspace_id
    end

    def invoice_is_posted
      errors.add(:invoice, "must be posted") if invoice && !invoice.posted?
    end

    def amount_does_not_exceed_balance
      return if invoice.blank? || amount_kobo.blank? || reverses_receivable_application.present?
      return if amount_kobo <= invoice.balance_due_kobo

      errors.add(:amount_kobo, "cannot exceed the invoice balance")
    end

    def journal_entry_matches_customer
      return if journal_entry.blank? || invoice.blank? || reverses_receivable_application.present?

      matching_credit = journal_entry.journal_entry_lines.any? do |line|
        line.credit_kobo.positive? && line.account.role == "receivable" && line.counterparty == invoice.customer
      end
      errors.add(:journal_entry, "must record a receivable credit for the invoice customer") unless matching_credit
    end

    def reversal_matches_original
      return if reverses_receivable_application.blank?

      original = reverses_receivable_application
      errors.add(:reverses_receivable_application, "must belong to the workspace") if original.workspace_id != workspace_id
      errors.add(:invoice, "must match the original application") if original.invoice_id != invoice_id
      errors.add(:amount_kobo, "must match the original application") if original.amount_kobo != amount_kobo
      unless journal_entry&.reverses_journal_entry_id == original.journal_entry_id
        errors.add(:journal_entry, "must reverse the original receipt")
      end
    end
end
