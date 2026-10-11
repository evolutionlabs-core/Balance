module LedgerSubtypes
  SUBTYPES = {
    "asset" => %w[cash accounts_receivable inventory fixed_asset accumulated_depreciation other_asset investment],
    "liability" => %w[accounts_payable credit_card tax_payable loan other_liability],
    "equity" => %w[owner_equity owner_draws retained_earnings opening_balance_equity],
    "income" => %w[operating other salary],
    "expense" => %w[cogs payroll rent marketing professional_fees depreciation other_expense housing groceries]
  }.freeze

  def self.valid?(subtype)
    SUBTYPES.values.flatten.include?(subtype)
  end
end
