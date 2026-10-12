class ExpenseLine < ApplicationRecord
  belongs_to :expense, inverse_of: :expense_lines
  belongs_to :account, class_name: "LedgerAccount"

  validates :description, presence: true
  validates :amount_kobo, numericality: { only_integer: true, greater_than: 0 }, unless: :invalid_amount_input?
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :account_belongs_to_workspace
  validate :account_is_eligible
  validate :account_is_not_payment_account
  validate :amount_input_is_valid

  before_update { throw(:abort) if expense.posted? }
  before_destroy { throw(:abort) if expense.posted? }

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
      return if account.blank? || expense.blank? || expense.workspace_id.blank?
      return if account.ledger.workspace_id == expense.workspace_id

      errors.add(:account, "must belong to the workspace")
    end

    def account_is_eligible
      return if account.blank? || account.base_type == "expense"

      errors.add(:account, "is not an eligible expense category")
    end

    def account_is_not_payment_account
      return if account.blank? || expense.blank?
      return unless account_id == expense.payment_account_id

      errors.add(:account, "cannot also be the payment account")
    end
end
