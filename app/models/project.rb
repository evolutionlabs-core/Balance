class Project < ApplicationRecord
  belongs_to :workspace
  belongs_to :customer
  has_many :estimates, dependent: :destroy
  has_many :tasks, class_name: "ProjectTask", dependent: :destroy
  has_many :time_entries, class_name: "ProjectTimeEntry", dependent: :destroy

  validates :name, presence: true
  validates :currency_code, inclusion: { in: %w[NGN] }
  validates :cost_budget_kobo, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :customer_belongs_to_workspace

  scope :ordered, -> { order(:name) }

  def summary
    Projects::Summary.new(self)
  end

  def cost_budget
    if cost_budget_kobo
      BigDecimal(cost_budget_kobo) / 100
    end
  end

  def cost_budget=(value)
    self.cost_budget_kobo = value.present? ? (BigDecimal(value.to_s) * 100).round : nil
  end

  private
    def customer_belongs_to_workspace
      return if customer.blank? || workspace.blank?
      return if customer.workspace_id == workspace_id

      errors.add(:customer, "must belong to the workspace")
    end
end
