class Service < ApplicationRecord
  belongs_to :workspace
  belongs_to :income_account, class_name: "Account"
  has_many :estimate_line_items, dependent: :restrict_with_error
  has_many :invoice_lines, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :default_rate_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :income_account_belongs_to_workspace
  validate :income_account_is_income

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def default_rate
    if default_rate_minor
      BigDecimal(default_rate_minor) / 100
    end
  end

  def default_rate=(value)
    self.default_rate_minor = value.present? ? (BigDecimal(value.to_s) * 100).round : nil
  end

  private
    def income_account_belongs_to_workspace
      return if income_account.blank? || workspace.blank?
      return if income_account.workspace_id == workspace_id

      errors.add(:income_account, "must belong to the workspace")
    end

    def income_account_is_income
      return if income_account.blank? || income_account.base_type == "income"

      errors.add(:income_account, "must be an income account")
    end
end
