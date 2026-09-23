require "test_helper"

class LlmJournalEntryProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
  end

  test "parses decimal naira exactly into kobo" do
    draft = build_draft(amount: "2500.10")

    assert draft.valid?
    assert_equal 250_010, draft.data.fetch("lines").first.fetch("amount_kobo")
  end

  test "rejects the same account on both sides" do
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Invalid transfer",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @cash.id, side: "debit", amount_naira: "100" },
        { account_id: @cash.id, side: "credit", amount_naira: "100" }
      ]
    )

    assert_includes draft.errors, "Account(s) used on both sides: #{@cash.id}"
  end

  test "rejects duplicate identical lines" do
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Duplicate lines",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "100" },
        { account_id: @expense.id, side: "debit", amount_naira: "100" },
        { account_id: @cash.id, side: "credit", amount_naira: "200" }
      ]
    )

    assert_includes draft.errors, "duplicate journal lines are not allowed"
  end

  test "rejects future dates" do
    draft = build_draft(amount: "100", entry_date: (Date.current + 1.day).to_s)

    assert_includes draft.errors, "Entry date cannot be in the future"
  end

  test "resolves an existing workspace customer as the journal line counterparty" do
    customer = @workspace.customers.create!(name: "Known Customer", customer_type: "business", email: "known@example.com")
    receivable = Account.for_role!(@workspace, :receivable)
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Customer receipt",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @cash.id, side: "debit", amount_naira: "100", counterparty_name: nil },
        { account_id: receivable.id, side: "credit", amount_naira: "100", counterparty_name: customer.name }
      ]
    )

    assert draft.valid?, draft.errors.to_sentence
    assert_equal customer.id, draft.data.fetch("lines").last.fetch("counterparty_id")
    assert_equal customer, draft.entry.journal_entry_lines.last.counterparty
  end

  test "rejects an unknown workspace customer counterparty" do
    receivable = Account.for_role!(@workspace, :receivable)
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Unknown customer receipt",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @cash.id, side: "debit", amount_naira: "100" },
        { account_id: receivable.id, side: "credit", amount_naira: "100", counterparty_name: "Missing Customer" }
      ]
    )

    assert_includes draft.errors, 'Customer "Missing Customer" does not exist in this workspace'
  end

  test "requires a customer on an accounts receivable credit" do
    receivable = Account.for_role!(@workspace, :receivable)
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Unassigned customer receipt",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @cash.id, side: "debit", amount_naira: "100" },
        { account_id: receivable.id, side: "credit", amount_naira: "100" }
      ]
    )

    assert_includes draft.errors, "Accounts Receivable credit must name an existing customer"
  end

  test "does not require ordinary transaction counterparties to be customers" do
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Vendor expense",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "100", counterparty_name: "Local Vendor" },
        { account_id: @cash.id, side: "credit", amount_naira: "100" }
      ]
    )

    assert draft.valid?, draft.errors.to_sentence
  end

  private

  def build_draft(amount:, entry_date: Date.current.to_s)
    Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Office expense",
      entry_date: entry_date,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: amount },
        { account_id: @cash.id, side: "credit", amount_naira: amount }
      ]
    )
  end
end
