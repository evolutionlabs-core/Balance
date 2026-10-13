require "test_helper"

class Llm::EntryProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Entry test"),
      title: "Entry test"
    )
  end

  test "parses decimal naira exactly into kobo" do
    draft = build_draft(amount: "2500.10")

    assert draft.valid?
    assert_equal 250_010, draft.data.fetch("lines").first.fetch("amount_kobo")
  end

  test "accepts a balanced two-line draft" do
    assert build_draft.valid?, build_draft.errors.join(", ")
  end

  test "rejects an unbalanced entry" do
    draft = Llm::EntryProposal.from_tool(
      workspace: @workspace,
      description: "Unbalanced",
      effective_date: Date.current.to_s,
      lines: [
        { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: @cash.id, side: "credit", amount_naira: "2000" }
      ]
    )

    assert_includes draft.errors, "Total debits (2500.00) must equal total credits (2000.00)"
  end

  test "rejects accounts outside the workspace ledger" do
    other_ledger = workspaces(:bola_shop).provision_ledger!(template: "standard_sme")
    foreign_cash = other_ledger.ledger_accounts.find_by!(name: "Bank")

    draft = build_draft(
      lines: [
        { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: foreign_cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_includes draft.errors, "Line 2: choose an account in this workspace"
  end

  test "requires a description and a parseable date" do
    draft = build_draft(description: "", effective_date: "12/45/2026")

    assert_includes draft.errors, "Description can't be blank"
    assert_includes draft.errors, "Effective date is not a valid date"
  end

  test "requires at least two lines" do
    draft = build_draft(
      lines: [ { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" } ]
    )

    assert_includes draft.errors, "An entry requires at least two lines"
  end

  test "records the entry through the engine" do
    proposal = @chat.proposals.create!(workspace: @workspace, proposal_type: "entry", version: 1, data: entry_data)

    assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: entry_data))

    entry = proposal.reload.ledger_entry
    assert_equal "Entry", entry.source_type
    assert_equal proposal.id, entry.source_id
    assert_equal "create", entry.action
    assert_equal 250_000, entry.ledger_lines.sum(&:debit)
    assert_equal 250_000, entry.ledger_lines.sum(&:credit)
  end

  test "a duplicate posting is rejected instead of crashing" do
    proposal = @chat.proposals.create!(workspace: @workspace, proposal_type: "entry", version: 1, data: entry_data)
    assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: entry_data))

    duplicate = Llm::EntryProposal.new(workspace: @workspace, data: entry_data)
    receipt = duplicate.post!(source_id: proposal.id)

    assert_equal false, receipt.success?
    assert_equal [ "This entry has already been recorded." ], receipt.errors
  end

  test "records a reversal with mirrored lines through the engine" do
    entry = record_entry(amount_kobo: 250_000)
    reversal_data = reversal_data(entry)

    proposal = @chat.proposals.create!(workspace: @workspace, proposal_type: "entry", version: 2, data: reversal_data)
    assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: reversal_data))

    reversal = proposal.reload.ledger_entry
    assert_equal "reverse", reversal.action
    assert_equal entry.ledger_lines.sum(&:debit), reversal.ledger_lines.sum(&:credit)
  end

  test "rejects reversing a posting from another feature" do
    entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: @groceries,
      credit_ledger_account: @cash,
      amount_kobo: 100_00
    )

    draft = Llm::EntryProposal.new(workspace: @workspace, data: reversal_data(entry))

    assert_includes draft.errors, "Only entries recorded from chat can be reversed"
  end

  test "rejects reversing an unknown entry" do
    draft = Llm::EntryProposal.new(workspace: @workspace, data: reversal_data(LedgerEntry.new(id: 999_999)))

    assert_includes draft.errors, "Original entry not found in this workspace"
  end

  test "rejects a second reversal of the same entry" do
    entry = record_entry(amount_kobo: 250_000)
    reversal_data = reversal_data(entry)
    record_entry(data: reversal_data)

    second_reversal = Llm::EntryProposal.new(workspace: @workspace, data: reversal_data(entry))

    assert_includes second_reversal.errors, "Entry ##{entry.id} has already been reversed"
  end

  test "rejects reversing a reversal" do
    entry = record_entry(amount_kobo: 250_000)
    reversal_entry = record_entry(data: reversal_data(entry))

    draft = Llm::EntryProposal.new(workspace: @workspace, data: reversal_data(reversal_entry))

    assert_includes draft.errors, "This entry is itself a reversal"
  end

  private
    def build_draft(amount: "2500", description: "Office expense", effective_date: Date.current.to_s, lines: [
      { ledger_account_id: @groceries.id, side: "debit", amount_naira: amount },
      { ledger_account_id: @cash.id, side: "credit", amount_naira: amount }
    ])
      Llm::EntryProposal.from_tool(
        workspace: @workspace,
        description: description,
        effective_date: effective_date,
        lines: lines
      )
    end

    def entry_data
      {
        "description" => "Office expense",
        "effective_date" => Date.current.to_s,
        "lines" => [
          { "ledger_account_id" => @groceries.id, "side" => "debit", "amount_kobo" => 250_000 },
          { "ledger_account_id" => @cash.id, "side" => "credit", "amount_kobo" => 250_000 }
        ]
      }
    end

    def reversal_data(entry)
      {
        "description" => "Reversal of entry ##{entry.id}: #{entry.description}",
        "effective_date" => Date.current.to_s,
        "amount_source" => "existing_posted_entry",
        "reverses_ledger_entry_id" => entry.id,
        "lines" => [
          { "ledger_account_id" => @cash.id, "side" => "debit", "amount_kobo" => 250_000 },
          { "ledger_account_id" => @groceries.id, "side" => "credit", "amount_kobo" => 250_000 }
        ]
      }
    end

    def record_entry(amount_kobo: nil, data: nil)
      data ||= entry_data
      proposal = @chat.proposals.create!(
        workspace: @workspace,
        proposal_type: "entry",
        version: (@chat.proposals.maximum(:version) || 0) + 1,
        data: data
      )
      assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: proposal.data))
      proposal.reload.ledger_entry
    end
end
