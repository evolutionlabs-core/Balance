class Account < ApplicationRecord
  belongs_to :ledger
  has_many :journal_entry_lines, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }

  before_validation :derive_normal_balance
  before_destroy :protect_system_account

  validate :subtype_belongs_to_base_type
  validate :system_account_stays_active

  def control_counterparty
    AccountSubtypes.control_counterparty(subtype)
  end

  private
    def derive_normal_balance
      self.normal_balance = AccountSubtypes.normal_balance(base_type, subtype)
    end

    def subtype_belongs_to_base_type
      unless AccountSubtypes.valid?(base_type, subtype)
        errors.add(:subtype, "is not a #{base_type.presence || "valid"} subtype")
      end
    end

    def system_account_stays_active
      errors.add(:active, "can't be turned off for a system account") if system? && !active?
    end

    def protect_system_account
      if system?
        errors.add(:base, "System accounts can't be deleted")
        throw :abort
      end
    end
end
