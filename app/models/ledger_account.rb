class LedgerAccount < ApplicationRecord
  DEBIT_BALANCE_TYPES = %w[asset expense].freeze

  belongs_to :ledger
  has_many :ledger_lines, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }


  before_validation :derive_normal_balance

  private
    def derive_normal_balance
      return if base_type.blank?

      self.normal_balance = if DEBIT_BALANCE_TYPES.include?(base_type)
        "debit"
      else
        "credit"
      end
    end
end
