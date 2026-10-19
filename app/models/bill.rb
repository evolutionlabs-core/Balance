class Bill < ApplicationRecord
  include AASM
  include Bills::Posting

  STATUSES = %w[draft open paid voided].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :vendor
  has_many :bill_lines, -> { order(:position) }, inverse_of: :bill, dependent: :destroy
  has_many :payments, class_name: "BillPayment", dependent: :restrict_with_error

  accepts_nested_attributes_for :bill_lines, allow_destroy: true, reject_if: :blank_line_attributes?

  validates :status, inclusion: { in: STATUSES }
  validates :bill_number, uniqueness: { scope: :vendor_id }, allow_blank: true
  validate :workspace_is_business
  validate :vendor_belongs_to_workspace
  validate :at_least_one_line

  before_validation :normalize_bill_number
  before_validation :calculate_total
  before_update { throw(:abort) if content_frozen? }
  before_destroy { throw(:abort) unless draft? }

  scope :outstanding, -> { where(status: "open") }

  aasm column: :status do
    state :draft, initial: true
    state :open, :paid, :voided

    event :enter do
      transitions from: :draft, to: :open
    end

    event :pay do
      transitions from: :open, to: :paid, guard: :fully_paid?
    end

    event :mark_voided do
      transitions from: :draft, to: :voided
      transitions from: :open, to: :voided, guard: :nothing_applied?
    end
  end

  def display_name
    bill_number.present? ? "Bill #{bill_number}" : "Bill ##{id}"
  end

  def applied_amount_kobo
    if payments.loaded?
      payments.sum(&:effective_amount_kobo)
    else
      payments.sum(
        Arel.sql("CASE WHEN reverses_bill_payment_id IS NULL THEN amount_kobo ELSE -amount_kobo END")
      )
    end
  end

  def balance_due_kobo
    [ total_kobo - applied_amount_kobo, 0 ].max
  end

  private
    def fully_paid?
      balance_due_kobo.zero?
    end

    def nothing_applied?
      applied_amount_kobo.zero?
    end

    def content_frozen?
      status_in_database != "draft" && (changes.keys - %w[status updated_at]).any?
    end

    def workspace_is_business
      return if workspace.blank? || workspace.business?

      errors.add(:base, "Bills are only available in business workspaces")
    end

    def vendor_belongs_to_workspace
      return if vendor.blank? || vendor.workspace_id == workspace_id

      errors.add(:vendor, "must belong to the workspace")
    end

    def at_least_one_line
      errors.add(:bill_lines, "must include at least one line") if active_lines.empty?
    end

    def blank_line_attributes?(attributes)
      return false if attributes["id"].present? || attributes[:id].present?

      attributes.values_at("account_id", :account_id, "description", :description, "amount", :amount).all?(&:blank?)
    end

    def normalize_bill_number
      self.bill_number = bill_number.to_s.strip.presence
    end

    def calculate_total
      active_lines.each_with_index { |line, position| line.position = position }
      self.total_kobo = active_lines.sum { |line| line.amount_kobo || 0 }
    end

    def active_lines
      bill_lines.reject(&:marked_for_destruction?)
    end
end
