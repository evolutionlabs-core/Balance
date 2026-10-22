class EstimateLineItem < ApplicationRecord
  belongs_to :estimate, touch: true
  belongs_to :service, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :rate_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :service_belongs_to_workspace

  before_validation :calculate_amount

  def rate
    if rate_minor
      BigDecimal(rate_minor) / 100
    end
  end

  def rate=(value)
    self.rate_minor = value.present? ? (BigDecimal(value.to_s) * 100).round : nil
  end

  def amount
    BigDecimal(amount_minor) / 100
  end

  def amount=(value)
    @amount_assigned = true
    self.amount_minor = value.present? ? (BigDecimal(value.to_s) * 100).round : 0
  end

  def calculate_amount
    if !@amount_assigned && quantity.present? && rate_minor.present?
      self.amount_minor = (quantity * rate_minor).round
    elsif !@amount_assigned
      self.amount_minor = 0
    end
  end

  private
    def service_belongs_to_workspace
      return if service.blank? || estimate.blank?
      return if service.workspace_id == estimate.workspace_id

      errors.add(:service, "must belong to the workspace")
    end
end
