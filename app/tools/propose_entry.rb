class ProposeEntry < RubyLLM::Tool
  description "Propose a balanced double-entry journal entry using account IDs returned by list_accounts. " \
              "Every required account must already exist. This creates a reviewable proposal only; " \
              "it never posts an entry. Amounts are in naira. For ordinary transactions, debit expenses " \
              "and assets received, and credit income, liabilities incurred, equity increases, and assets paid out. " \
              "Before calling, sum the proposed line amounts and verify that total debits exactly equal total credits."

  parameters do
    string :description, description: "short, clear description of the transaction"
    string :entry_date, required: false,
                        description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today"
    array :lines, description: "at least two debit or credit lines that balance" do
      object do
        number :account_id, description: "account ID returned by list_accounts"
        string :side, enum: %w[debit credit], description: "whether this line is a debit or credit"
        string :amount_naira, description: "positive amount in naira as a decimal string, e.g. \"4550.50\""
        string :counterparty_name, required: false, description: "person or organisation on the other side"
      end
    end
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(description:, lines:, entry_date: nil)
    missing_accounts = required_created_accounts.reject do |account|
      lines.any? do |line|
        attributes = line.to_h
        (attributes[:account_id] || attributes["account_id"]).to_i == account.id
      end
    end
    if missing_accounts.any?
      required = missing_accounts.map { |account| "#{account.name} (id #{account.id})" }.join(", ")
      return { error: "Use every account just created for this transaction. Missing: #{required}." }
    end

    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: description,
      entry_date: entry_date,
      lines: lines
    )

    return { error: draft.errors.join(", ") } if draft.invalid?

    {
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: draft.data,
      message: "Journal-entry proposal created for review."
    }
  end

  private

  def required_created_accounts
    turn = @chat.active_turn if @chat.respond_to?(:active_turn)
    return Account.none unless turn&.user_message&.role == "system"

    proposal = @chat.proposals.by_type("account_creation").where(status: "confirmed").order(id: :desc).first
    ids = proposal&.data&.fetch("created_accounts", [])&.pluck("id")
    @workspace.accounts.where(id: ids)
  end
end
