class InvoiceLine < ApplicationRecord
  belongs_to :invoice
  belongs_to :account, optional: true
  belongs_to :service, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :rate_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :account_belongs_to_workspace
  validate :service_belongs_to_workspace

  before_validation :calculate_amount
  before_validation :snapshot_income_account
  before_create { throw(:abort) if invoice.persisted? && invoice.posted? }
  before_update { throw(:abort) if invoice.posted? }
  before_destroy { throw(:abort) if invoice.posted? }

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
    def snapshot_income_account
      if service_id_changed? || (account_id.nil? && !account_id_changed?)
        self.account = service&.income_account || invoice.workspace.default_sales_account
      end
    end

    def service_belongs_to_workspace
      return if service.blank? || invoice.blank?
      return if service.workspace_id == invoice.workspace_id

      errors.add(:service, "must belong to the workspace")
    end

    def account_belongs_to_workspace
      return if account.blank? || invoice.blank?
      return if account.workspace_id == invoice.workspace_id

      errors.add(:account, "must belong to the workspace")
    end
end
