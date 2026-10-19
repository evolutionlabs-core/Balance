class BillLine < ApplicationRecord
  # Bills can be charged to an expense or to an asset that is bought on credit.
  ASSET_SUBTYPES = %w[inventory fixed_asset other_asset].freeze

  belongs_to :bill, inverse_of: :bill_lines
  belongs_to :account

  validates :description, presence: true
  validates :amount_kobo, numericality: { only_integer: true, greater_than: 0 }, unless: :invalid_amount_input?
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :account_belongs_to_workspace
  validate :account_is_eligible
  validate :amount_input_is_valid

  before_create { throw(:abort) if bill.persisted? && bill.status_in_database != "draft" }
  before_update { throw(:abort) if bill.status_in_database != "draft" }
  before_destroy { throw(:abort) if bill.status_in_database != "draft" }

  def self.eligible_account?(account)
    account.base_type == "expense" || (account.base_type == "asset" && ASSET_SUBTYPES.include?(account.subtype))
  end

  def amount
    return @amount_input if defined?(@amount_input)
    return nil if amount_kobo.nil?

    BigDecimal(amount_kobo) / 100
  end

  def amount=(value)
    @amount_input = value
    @invalid_amount_input = false
    if value.blank?
      self.amount_kobo = nil
    else
      decimal = BigDecimal(value.to_s)
      kobo = decimal * 100
      raise ArgumentError unless decimal.finite? && kobo == kobo.to_i

      self.amount_kobo = kobo.to_i
    end
  rescue ArgumentError, FloatDomainError
    @invalid_amount_input = true
    self.amount_kobo = nil
  end

  private
    def invalid_amount_input?
      @invalid_amount_input
    end

    def amount_input_is_valid
      errors.add(:amount, "must be a valid number") if invalid_amount_input?
    end

    def account_belongs_to_workspace
      return if account.blank? || bill.blank? || bill.workspace_id.blank?
      return if account.ledger.workspace_id == bill.workspace_id

      errors.add(:account, "must belong to the workspace")
    end

    def account_is_eligible
      return if account.blank? || self.class.eligible_account?(account)

      errors.add(:account, "must be an expense, inventory, or fixed asset account")
    end
end
