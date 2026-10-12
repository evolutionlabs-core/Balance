class Workspace < ApplicationRecord
  belongs_to :default_sales_account, class_name: "Account", optional: true
  enum :workspace_type, { personal: "personal", business: "business" }, validate: true

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :journal_entries, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :ledgers, dependent: :restrict_with_error
  has_many :invoices, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :estimates, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :receivable_applications, dependent: :restrict_with_error
  has_many :llm_chats, class_name: "Llm::Chat", dependent: :destroy
  has_many :proposals, dependent: :destroy

  validates :name, presence: true
  validates :currency_code, inclusion: { in: %w[NGN] }
  validate :default_sales_account_is_workspace_income

  def catalog
    AccountCatalog.for(workspace_type)
  end

  def ledger_template
    personal? ? "personal_finance" : "standard_sme"
  end

  def payment_accounts
    ledger_accounts.where(subtype: %w[cash credit_card])
  end

  def expense_categories
    ledger_accounts.where(base_type: "expense")
  end

  def receipt_accounts
    account_type = business? ? "Bank" : "Cash & Liquid Assets"
    cash_accounts = accounts.where(base_type: "asset", account_type: account_type)
    cash_accounts.where(role: nil).or(cash_accounts.where.not(role: "suspense")).ordered
  end

  def seed_core_accounts!
    catalog.core.each_key { |role| Account.for_role!(self, role) }
  end

  private
    def ledger_accounts
      LedgerAccount.where(ledger: ledgers)
    end

    def default_sales_account_is_workspace_income
      return if default_sales_account.blank?

      unless default_sales_account.workspace_id == id && default_sales_account.base_type == "income"
        errors.add(:default_sales_account, "must be an income account in this workspace")
      end
    end
end
