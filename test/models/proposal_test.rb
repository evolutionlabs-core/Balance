require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @expense = @ledger.ledger_accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "entry",
      version: 1,
      data: {
        "description" => "Office supplies",
        "effective_date" => Date.current.to_s,
        "lines" => [
          { "ledger_account_id" => @expense.id, "side" => "debit", "amount_kobo" => 250_000 },
          { "ledger_account_id" => @cash.id, "side" => "credit", "amount_kobo" => 250_000 }
        ]
      }
    )
  end

  test "confirm! posts through the engine and marks the proposal confirmed" do
    assert_difference "LedgerEntry.count", 1 do
      assert_nil @proposal.confirm!(draft: build_draft)
    end

    assert_equal "confirmed", @proposal.reload.status
    assert_not_nil @proposal.ledger_entry
    entry = @proposal.ledger_entry
    assert_equal "Entry", entry.source_type
    assert_equal @proposal.id, entry.source_id
    assert_equal "create", entry.action
    assert_equal 250_000.to_d, entry.ledger_lines.sum(&:debit)
    assert_equal 250_000.to_d, entry.ledger_lines.sum(&:credit)
  end

  test "double-confirm posts exactly one entry" do
    assert_difference "LedgerEntry.count", 1 do
      @proposal.confirm!(draft: build_draft)
      @proposal.confirm!(draft: build_draft)
    end

    assert_equal "confirmed", @proposal.reload.status
  end

  test "confirm! is a no-op once the proposal is no longer pending" do
    @proposal.confirm!(draft: build_draft)
    @proposal.update!(status: "dismissed", ledger_entry: nil)

    assert_no_difference "LedgerEntry.count" do
      assert_equal [], @proposal.confirm!(draft: build_draft)
    end

    assert_equal "dismissed", @proposal.reload.status
  end

  test "confirm! returns the draft errors without posting anything" do
    draft = build_draft(lines: [ { ledger_account_id: @expense.id, side: "debit", amount_naira: "2500" } ])

    assert_no_difference "LedgerEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "An entry requires at least two lines"
    end

    assert_equal "proposed", @proposal.reload.status
    assert_nil @proposal.ledger_entry
  end

  test "confirm! does not post an unbalanced draft" do
    draft = build_draft(
      lines: [
        { ledger_account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: @cash.id, side: "credit", amount_naira: "2000" }
      ]
    )

    assert_no_difference "LedgerEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "Total debits (2500.00) must equal total credits (2000.00)"
    end

    assert_equal "proposed", @proposal.reload.status
  end

  test "confirm! refuses a draft whose ledger account belongs to another workspace" do
    other_workspace = workspaces(:bola_shop)
    @other_ledger = other_workspace.provision_ledger!(template: "standard_sme")
    other_cash = @other_ledger.ledger_accounts.find_by!(name: "Cash")

    draft = build_draft(
      lines: [
        { ledger_account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: other_cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_no_difference "LedgerEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "Line 2: choose an account in this workspace"
    end

    assert_equal "proposed", @proposal.reload.status
  end

  test "a selection confirmation cannot be posted as an entry proposal" do
    draft = build_draft
    @proposal.update!(proposal_type: "reversal_confirmation")

    assert_no_difference "LedgerEntry.count" do
      assert_includes @proposal.confirm!(draft: draft), "Confirm the selected entry before reviewing its reversal proposal."
    end
  end

  private

  def build_draft(lines: nil)
    lines ||= [
      { ledger_account_id: @expense.id, side: "debit", amount_naira: "2500" },
      { ledger_account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ]

    Llm::EntryProposal.from_tool(
      workspace: @workspace,
      description: "Office supplies",
      effective_date: Date.current.to_s,
      lines: lines
    )
  end
end
