require "test_helper"

class ListJournalEntriesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")
    @model = Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model")
    @chat = Llm::Chat.create!(workspace: @workspace, llm_model: @model, title: "Test chat")
  end

  test "returns recorded entries from the current workspace" do
    entry = record_entry(
      description: "Weekly shop",
      effective_date: Date.new(2026, 8, 12),
      amount_kobo: 250_000
    )

    result = ListJournalEntries.new(@workspace).execute

    assert_equal [ entry.id ], result.map { |item| item[:id] }
    assert_equal "2026-08-12", result.first[:date]
    assert_equal "Weekly shop", result.first[:description]
    assert_equal "Entry", result.first[:source]
    assert_nil result.first[:reverses_ledger_entry_id]
    assert_equal "2500.00", result.first[:lines].find { |line| line[:debit_naira] != "0.00" }[:debit_naira]
    assert_equal "Groceries", result.first[:lines].find { |line| line[:debit_naira] != "0.00" }[:account]
  end

  test "filters by inclusive date range" do
    record_entry(effective_date: Date.new(2026, 8, 10), amount_kobo: 100)
    record_entry(effective_date: Date.new(2026, 8, 12), amount_kobo: 200)

    result = ListJournalEntries.new(@workspace).execute(from_date: "2026-08-12", to_date: "2026-08-12")

    assert_equal [ "2026-08-12" ], result.map { |item| item[:date] }
  end

  test "rejects an invalid date range" do
    result = ListJournalEntries.new(@workspace).execute(from_date: "2026-08-13", to_date: "2026-08-12")

    assert_equal "from_date cannot be after to_date", result[:error]
  end

  test "does not return entries from other workspaces" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = other_workspace.provision_ledger!(template: "standard_sme")
    other_chat = Llm::Chat.create!(workspace: other_workspace, llm_model: @model, title: "Other")
    record_entry(workspaces_chat: other_chat)

    assert_empty ListJournalEntries.new(@workspace).execute
  end

  test "marks entries that are themselves reversals via reverses_ledger_entry_id" do
    entry = record_entry(description: "Weekly shop", amount_kobo: 250_000)
    reversal = record_entry(
      description: "Reversal of entry ##{entry.id}",
      amount_kobo: 250_000,
      reverses_ledger_entry_id: entry.id
    )

    result = ListJournalEntries.new(@workspace).execute

    assert_nil result.find { |item| item[:id] == entry.id }[:reverses_ledger_entry_id]
    assert_equal entry.id, result.find { |item| item[:id] == reversal.id }[:reverses_ledger_entry_id]
  end

  private
    def record_entry(description: "Cash spent", effective_date: Date.current, amount_kobo: 250_000, reverses_ledger_entry_id: nil, workspaces_chat: nil)
      chat = workspaces_chat || @chat
      workspace = chat.workspace
      ledger = workspace.ledgers.first || workspace.provision_ledger!(template: workspace.ledger_template)
      original = reverses_ledger_entry_id && ledger.ledger_entries.where(id: reverses_ledger_entry_id).sole

      lines = if original
        original.ledger_lines.map do |line|
          {
            "ledger_account_id" => line.ledger_account_id,
            "side" => line.debit.positive? ? "credit" : "debit",
            "amount_kobo" => line.debit.positive? ? line.debit : line.credit
          }
        end
      else
        debit_account = ledger.ledger_accounts.where(base_type: "expense").ordered.first ||
          ledger.ledger_accounts.ordered.first
        credit_account = ledger.ledger_accounts.where(base_type: "asset").ordered.first ||
          ledger.ledger_accounts.ordered.second

        [
          { "ledger_account_id" => debit_account.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "ledger_account_id" => credit_account.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ]
      end

      data = { "description" => description, "effective_date" => effective_date.iso8601, "lines" => lines }
      data["reverses_ledger_entry_id"] = original.id if original
      proposal = chat.proposals.create!(
        workspace: workspace,
        proposal_type: "entry",
        version: (chat.proposals.maximum(:version) || 0) + 1,
        data: data
      )
      assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: workspace, data: proposal.data))
      proposal.reload.ledger_entry
    end
end
