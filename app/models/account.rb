class Account < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :restrict_with_error
  has_many :paid_expenses,
    class_name: "Expense",
    foreign_key: :payment_account_id,
    dependent: :restrict_with_error
  has_many :expense_lines, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :base_type, :account_type, :detail_type, presence: true
  validate :base_type_is_in_catalog
  validate :account_type_belongs_to_base_type
  validate :detail_type_belongs_to_account_type

  before_destroy { throw(:abort) if role.present? }
  before_update { throw(:abort) if role.present? && taxonomy_changed? }

  scope :ordered, -> { order(:name) }
  scope :expense_accounts, -> { where(base_type: "expense") }

  def self.for_role!(workspace, role)
    spec = workspace.catalog.account_spec(role)

    workspace.accounts.find_or_create_by!(role: role.to_s) do |a|
      a.name         = spec[:name]
      a.base_type    = spec[:base]
      a.account_type = spec[:type]
      a.detail_type  = spec[:detail]
    end
  end

  def normal_balance
    Accounting::Behaviour.normal_balance(base_type)
  end

  private

  def catalog
    workspace&.catalog
  end

  def catalog_category
    return if base_type.blank?

    catalog&.categories&.find { |category| category[:category].downcase == base_type }
  end

  def taxonomy_changed?
    base_type_changed? || account_type_changed? || detail_type_changed?
  end

  def base_type_is_in_catalog
    return if base_type.blank? || catalog_category

    errors.add(:base_type, "is not a valid base type")
  end

  def account_type_belongs_to_base_type
    return if base_type.blank? || account_type.blank?

    category = catalog_category
    return if category && category[:account_types].any? { |entry| entry[:account_type] == account_type }

    errors.add(:account_type, "is not valid for base type #{base_type}")
  end

  def detail_type_belongs_to_account_type
    return if base_type.blank? || account_type.blank? || detail_type.blank?

    return if catalog&.detail_types_for(account_type)&.include?(detail_type)

    errors.add(:detail_type, "is not valid for account type #{account_type}")
  end
end
