class CreditApplication < ApplicationRecord
  belongs_to :workspace
  belongs_to :credit_note
  belongs_to :invoice

  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validate :documents_share_customer_and_workspace

  before_update { throw(:abort) }

  private
    def documents_share_customer_and_workspace
      return if credit_note.blank? || invoice.blank?

      if credit_note.workspace_id != workspace_id || invoice.workspace_id != workspace_id
        errors.add(:base, "Credit and invoice must belong to the workspace")
      elsif credit_note.customer_id != invoice.customer_id
        errors.add(:base, "Credit and invoice must belong to the same customer")
      end
    end
end
