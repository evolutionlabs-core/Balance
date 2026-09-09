class InvoiceLine < ApplicationRecord
  belongs_to :invoice

  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :rate_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :calculate_amount

  def rate
    if rate_minor
      BigDecimal(rate_minor) / 100
    end
  end

  def rate=(value)
    self.rate_minor = value.present? ? (BigDecimal(value.to_s) * 100).round : nil
  end

  def calculate_amount
    if quantity.present? && rate_minor.present?
      self.amount_minor = (quantity * rate_minor).round
    else
      self.amount_minor = 0
    end
  end
end
