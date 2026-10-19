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
end
