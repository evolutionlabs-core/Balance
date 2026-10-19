class ProposeEntry < RubyLLM::Tool
  description "Propose a balanced entry you will prepare for the user to review before it is recorded through the ledger engine. " \
              "Every required account must already exist in the ledger chart. This creates a reviewable proposal only; " \
              "it never records anything. Amounts are in naira. For ordinary transactions, debit expenses " \
              "and assets received, and credit income, liabilities incurred, equity increases, and assets paid out. " \
              "Before calling, sum the proposed line amounts and verify that total debits exactly equal total credits."

  params do
    string :description, description: "short, clear description of the transaction"
    string :effective_date, required: false,
                            description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today"
    array :lines, description: "at least two debit or credit lines that balance" do
      object do
        number :account_id, description: "account ID returned by list_accounts"
        string :side, enum: %w[debit credit], description: "whether this line is a debit or credit"
        string :amount_naira, description: "positive amount in naira as a decimal string, e.g. \"4550.50\""
      end
    end
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(description:, lines:, effective_date: nil)
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

    draft = Llm::EntryProposal.from_tool(
      workspace: @workspace,
      description: description,
      effective_date: effective_date,
      lines: lines
    )

    return { error: draft.errors.join(", ") } if draft.invalid?

    halt({
      proposal: true,
      proposed_action: "entry",
      entry_data: draft.data,
      message: "Entry proposal created for review."
    })
  end

  private

  def required_created_accounts
    turn = @chat.active_turn if @chat.respond_to?(:active_turn)
    return Account.none unless turn&.user_message&.role == "system"

    proposal = @chat.proposals.by_type("account_creation").where(status: "confirmed").order(id: :desc).first
    ids = proposal&.data&.fetch("created_accounts", [])&.pluck("id")
    ledger.accounts.where(id: ids)
  end

  def ledger
    @ledger ||= @workspace.ledger
  end
end
