class Account < ApplicationRecord
  belongs_to :ledger
  has_many :journal_entry_lines, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false) }

  before_validation :derive_normal_balance
  before_destroy :protect_system_account

  validate :subtype_belongs_to_base_type
  validate :system_account_stays_active

  def control_counterparty
    AccountSubtypes.control_counterparty(subtype)
  end

  def balance
    sign = normal_balance == "debit" ? 1 : -1
    sign * AccountingEngine::Balances.new(ledger).by_account.fetch(id, 0)
  end

  def archive
    if system?
      errors.add(:base, "#{name} is a system account and can't be archived")
    elsif balance.nonzero?
      errors.add(:base, "#{name} still has a balance; move it to another account before archiving")
    else
      update(active: false)
    end

    errors.empty?
  end

  def restore
    update(active: true)
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
