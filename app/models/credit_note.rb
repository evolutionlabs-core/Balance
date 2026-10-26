class CreditNote < ApplicationRecord
  STAMPED_ATTRIBUTES = %w[journal_entry_id void_journal_entry_id voided_at].freeze

  belongs_to :workspace
  belongs_to :invoice
  belongs_to :user
  belongs_to :journal_entry, optional: true
  belongs_to :void_journal_entry, class_name: "JournalEntry", optional: true

  scope :active, -> { where(voided_at: nil) }

  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validates :issued_on, :reason, presence: true
  validate :invoice_belongs_to_workspace

  after_create :assign_number
  before_update { throw(:abort) unless stamping? }
  before_destroy { throw(:abort) }

  def voided?
    voided_at.present?
  end

  private
    def invoice_belongs_to_workspace
      return if invoice.blank? || invoice.workspace_id == workspace_id

      errors.add(:invoice, "must belong to the workspace")
    end

    def assign_number
      self.number = format("CN-%06d", id)
      update_column(:number, number)
    end

    def stamping?
      changes.except("updated_at").all? { |attribute, (from, _to)| STAMPED_ATTRIBUTES.include?(attribute) && from.nil? }
    end
end
