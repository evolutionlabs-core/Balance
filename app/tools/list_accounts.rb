class ListAccounts < RubyLLM::Tool
  description "Resolve accounts only after the current economic event is fully understood and every amount needed " \
              "to record it is known. If required facts or amounts are missing, ask the user before calling this tool. " \
              "State the economic purpose you are resolving so it remains explicit throughout the tool call. " \
              "Prefer a suitable existing account. If none fits, prefer a " \
              "recommended catalog account. If no recommendation fits, define a clear account name using the " \
              "returned valid taxonomy. Never substitute an unrelated account or invent an account ID."

  parameters do
    string :purpose, description: "short description of the current event with each known amount stated separately"
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(purpose:)
    existing = @workspace.accounts.ordered.to_a
    existing_taxonomy = existing.map { |account| [ account.base_type, account.account_type, account.detail_type ] }

    {
      purpose: purpose,
      selection_guidance: "Prefer suitable existing accounts. Represent the final economic substance with the " \
                          "fewest real accounts; do not add an intermediate account unless it retains a balance " \
                          "after the event. Debit expenses and assets received; credit income, liabilities incurred, " \
                          "and assets given up. Build totals from the journal lines: when an asset transfer also has " \
                          "a fee, the asset given up equals the transferred amount plus the fee.",
      existing_accounts: existing.map { |account| account_hash(account) },
      recommended_accounts: @workspace.catalog.recommended.values
        .reject { |spec| existing_taxonomy.include?([ spec[:base], spec[:type], spec[:detail] ]) }
        .map { |spec| recommended_hash(spec) },
      account_taxonomy: taxonomy
    }
  end

  private

  def account_hash(account)
    {
      id: account.id,
      name: account.name,
      base_type: account.base_type,
      account_type: account.account_type,
      detail_type: account.detail_type
    }
  end

  def recommended_hash(spec)
    {
      name: spec[:name],
      base_type: spec[:base],
      account_type: spec[:type],
      detail_type: spec[:detail]
    }
  end

  def taxonomy
    @workspace.catalog.categories.map do |category|
      {
        base_type: category.fetch(:category).downcase,
        account_types: category.fetch(:account_types).map do |account_type|
          {
            account_type: account_type.fetch(:account_type),
            detail_types: @workspace.catalog.detail_types_for(account_type.fetch(:account_type))
          }
        end
      }
    end
  end
end
