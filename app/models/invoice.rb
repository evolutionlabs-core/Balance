class Invoice < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :contact, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: "draft" }, validate: true

  validates :invoice_number, uniqueness: { scope: :workspace_id }, allow_nil: true

  before_validation :calculate_totals

  private
    def calculate_totals
      active_lines.each_with_index do |line, position|
        line.position = position
        line.calculate_amount
      end

      self.subtotal_minor = active_lines.sum { |line| line.amount_minor || 0 }
      self.total_minor = subtotal_minor
    end

    def active_lines
      invoice_lines.reject(&:marked_for_destruction?)
    end
end
