module AccountSubtypes
  SUBTYPES = {
    "asset" => %w[cash accounts_receivable inventory fixed_asset accumulated_depreciation other_asset investment],
    "liability" => %w[accounts_payable credit_card tax_payable loan other_liability],
    "equity" => %w[owner_equity owner_draws retained_earnings opening_balance_equity],
    "income" => %w[operating other salary],
    "expense" => %w[cogs payroll rent marketing professional_fees utilities depreciation other_expense housing groceries]
  }.freeze

  DEBIT_NORMAL_BASE_TYPES = %w[asset expense].freeze

  # Contra accounts carry the opposite balance of their base type.
  CONTRA_NORMAL_BALANCES = {
    "accumulated_depreciation" => "credit",
    "owner_draws" => "debit"
  }.freeze

  # Control accounts summarize a subledger; every line on one names the
  # counterparty it belongs to.
  CONTROL_COUNTERPARTIES = {
    "accounts_receivable" => "customer",
    "accounts_payable" => "vendor"
  }.freeze

  STATEMENT_GROUPS = {
    "cash" => "current_assets",
    "accounts_receivable" => "current_assets",
    "inventory" => "current_assets",
    "other_asset" => "current_assets",
    "fixed_asset" => "non_current_assets",
    "accumulated_depreciation" => "non_current_assets",
    "investment" => "non_current_assets",
    "accounts_payable" => "current_liabilities",
    "credit_card" => "current_liabilities",
    "tax_payable" => "current_liabilities",
    "other_liability" => "current_liabilities",
    "loan" => "non_current_liabilities",
    "owner_equity" => "equity",
    "owner_draws" => "equity",
    "retained_earnings" => "equity",
    "opening_balance_equity" => "equity",
    "operating" => "revenue",
    "salary" => "revenue",
    "other" => "other_income",
    "cogs" => "cost_of_sales",
    "payroll" => "operating_expenses",
    "rent" => "operating_expenses",
    "marketing" => "operating_expenses",
    "professional_fees" => "operating_expenses",
    "utilities" => "operating_expenses",
    "depreciation" => "operating_expenses",
    "other_expense" => "operating_expenses",
    "housing" => "operating_expenses",
    "groceries" => "operating_expenses"
  }.freeze

  def self.valid?(base_type, subtype)
    SUBTYPES.fetch(base_type.to_s, []).include?(subtype.to_s)
  end

  def self.normal_balance(base_type, subtype)
    CONTRA_NORMAL_BALANCES.fetch(subtype.to_s) do
      DEBIT_NORMAL_BASE_TYPES.include?(base_type.to_s) ? "debit" : "credit"
    end
  end

  def self.control_counterparty(subtype)
    CONTROL_COUNTERPARTIES[subtype.to_s]
  end

  def self.statement_group(subtype)
    STATEMENT_GROUPS.fetch(subtype.to_s)
  end
end
