class Workspace < ApplicationRecord
  include Ledgers::Provisioning
  include Workspaces::Creation

  belongs_to :default_sales_account, class_name: "Account", optional: true
  belongs_to :default_deposit_account, class_name: "Account", optional: true
  enum :workspace_type, { personal: "personal", business: "business" }, validate: true

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :expenses, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :ledgers, dependent: :restrict_with_error
  has_many :journal_entry_drafts, dependent: :destroy
  has_many :entry_templates, dependent: :destroy
  has_many :accounts, through: :ledgers
  has_many :invoices, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :estimates, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :invoice_payments, dependent: :restrict_with_error
  has_many :vendors, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :bill_payments, dependent: :restrict_with_error
  has_many :proposals, dependent: :destroy
  has_many :llm_chats, class_name: "Llm::Chat", dependent: :destroy

  validates :name, presence: true
  validates :currency_code, inclusion: { in: %w[NGN] }
  validate :default_sales_account_is_workspace_income
  validate :default_deposit_account_is_workspace_cash

  def ledger
    ledgers.sole
  end

  def payment_accounts
    accounts.where(subtype: %w[cash credit_card])
  end

  def deposit_accounts
    accounts.where(subtype: "cash")
  end

  def income_accounts
    accounts.where(base_type: "income")
  end

  def expense_categories
    accounts.where(base_type: "expense")
  end

  def owned_by?(user)
    return false if user.nil?

    memberships.owner.exists?(user: user)
  end

  private
    def default_sales_account_is_workspace_income
      return if default_sales_account.blank?

      unless default_sales_account.ledger.workspace_id == id && default_sales_account.base_type == "income"
        errors.add(:default_sales_account, "must be an income account in this workspace")
      end
    end

    def default_deposit_account_is_workspace_cash
      return if default_deposit_account.blank?

      unless default_deposit_account.ledger.workspace_id == id && default_deposit_account.subtype == "cash"
        errors.add(:default_deposit_account, "must be a bank or cash account in this workspace")
      end
    end
end
