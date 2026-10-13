class ListAccounts < RubyLLM::Tool
  description "Resolve ledger accounts only after the current economic event is fully understood and every amount needed " \
              "to record it is known. If required facts or amounts are missing, ask the user before calling this tool. " \
              "State the economic purpose you are resolving so it remains explicit throughout the tool call. " \
              "Prefer a suitable existing account. If none fits, prefer a " \
              "recommended chart account. If no recommendation fits, define a clear account name using the " \
              "returned valid taxonomy. Never substitute an unrelated account or invent an account ID."

  params do
    string :purpose, description: "short description of the current event with each known amount stated separately"
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(purpose:)
    existing = ledger.ledger_accounts.ordered.to_a
    existing_names = existing.map(&:name).map(&:downcase)

    {
      purpose: purpose,
      selection_guidance: "Prefer suitable existing ledger accounts. Represent the final economic substance with the " \
                          "fewest real accounts; do not add an intermediate account unless it retains a balance " \
                          "after the event. Debit expenses and assets received; credit income, liabilities incurred, " \
                          "and assets given up. Build totals from the entry lines: when an asset transfer also has " \
                          "a fee, the asset given up equals the transferred amount plus the fee.",
      existing_accounts: existing.map { |account| account_hash(account) },
      recommended_accounts: chart_rows
        .reject { |row| existing_names.include?(row["name"].downcase) }
        .map { |row| recommended_hash(row) },
      account_taxonomy: taxonomy
    }
  end

  private

  def account_hash(account)
    {
      id: account.id,
      name: account.name,
      code: account.code,
      base_type: account.base_type,
      subtype: account.subtype,
      balance_kobo: balance_for(account)
    }
  end

  def balance_for(account)
    LedgerLine.joins(:ledger_entry)
      .where(ledger_entries: { ledger_id: ledger.id })
      .where(ledger_account_id: account.id)
      .sum("ledger_lines.debit - ledger_lines.credit").to_i
  end

  def recommended_hash(row)
    {
      name: row["name"],
      code: row["code"],
      base_type: row["base_type"],
      subtype: row["subtype"]
    }
  end

  def chart_rows
    YAML.load_file(Rails.root.join("config/charts/#{@workspace.ledger_template}.yml")).fetch("accounts")
  end

  def taxonomy
    LedgerSubtypes::SUBTYPES.map do |base_type, subtypes|
      { base_type: base_type, subtypes: subtypes }
    end
  end

  def ledger
    @ledger ||= @workspace.ledgers.first ||
      @workspace.provision_ledger!(template: @workspace.ledger_template)
  end
end
