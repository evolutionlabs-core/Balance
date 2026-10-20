class ProposeAccount < RubyLLM::Tool
  description "Propose missing ledger chart accounts for the user to review. This never creates an account. " \
              "Use it only when list_accounts results from the current request prove that a required account is " \
              "missing and supply the valid ledger taxonomy. Never call it before list_accounts. A request to " \
              "use separate accounts does not itself mean new accounts are missing."

  parameters do
    string :reason, description: "plain-language reason these accounts are needed for the transaction"
    array :accounts, description: "missing accounts to present together for approval" do
      object do
        string :name, description: "clear account name"
        string :base_type, enum: AccountSubtypes::SUBTYPES.keys
        string :subtype, description: "account subtype from the ledger taxonomy"
      end
    end
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(reason:, accounts:)
    draft = Llm::AccountCreationProposal.from_tool(workspace: @workspace, reason: reason, accounts: accounts)
    return { error: draft.errors.join(", ") } if draft.invalid?

    {
      proposal: true,
      proposed_action: "account_creation",
      entry_data: draft.data,
      message: "Account proposal created for review."
    }
  end
end
