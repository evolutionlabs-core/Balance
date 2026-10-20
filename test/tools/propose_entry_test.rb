require "test_helper"

class ProposeEntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @chat = stub_llm_chat(workspace: @workspace, prompt: "Paid ₦2,500 cash for supplies")
  end

  test "proposes a balanced entry using existing account IDs" do
    result = execute_tool

    assert result[:proposal]
    assert_equal "entry", result[:proposed_action]
    assert_equal [ @groceries.id, @cash.id ], result.dig(:entry_data, "lines").pluck("account_id")
  end

  test "rejects a missing account ID instead of bypassing account approval" do
    result = execute_tool(lines: [
      { side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Line 1: choose an account in this workspace"
  end

  test "rejects an account from another workspace" do
    other_ledger = provision_business_ledger!(workspaces(:bola_shop))
    foreign_bank = other_ledger.accounts.find_by!(name: "Bank")
    result = execute_tool(lines: [
      { account_id: @groceries.id, side: "debit", amount_naira: "2500" },
      { account_id: foreign_bank.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Line 2: choose an account in this workspace"
  end

  test "rejects an unbalanced entry" do
    result = execute_tool(lines: [
      { account_id: @groceries.id, side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2000" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Total debits (2500.00) must equal total credits (2000.00)"
  end

  test "requires every account created for the resumed transaction" do
    tax = @ledger.accounts.create!(name: "Tax Expense", base_type: "expense", subtype: "other_expense", code: "9510", created_by: "admin")
    chat = Llm::Chat.create!(workspace: @workspace, model: ruby_llm_models(:default), title: "Resumed transaction")
    chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      status: "confirmed",
      data: {
        "reason" => "Track tax separately",
        "accounts" => [],
        "created_accounts" => [ { "id" => tax.id, "name" => tax.name } ]
      }
    )
    message = chat.llm_messages.create!(role: "system", content: "Continue the pending transaction")
    chat.active_turn = chat.llm_turns.create!(user_message: message)

    result = ProposeEntry.new(chat).execute(
      description: "Salary with tax",
      effective_date: Date.current.to_s,
      lines: [
        { account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_includes result[:error], "Tax Expense (id #{tax.id})"

    corrected = ProposeEntry.new(chat).execute(
      description: "Salary with tax",
      effective_date: Date.current.to_s,
      lines: [
        { "account_id" => @groceries.id, "side" => "debit", "amount_naira" => "2000" },
        { "account_id" => tax.id, "side" => "debit", "amount_naira" => "500" },
        { "account_id" => @cash.id, "side" => "credit", "amount_naira" => "2500" }
      ]
    )

    assert corrected[:proposal]
    assert_equal "entry", corrected[:proposed_action]
  end

  private
    def execute_tool(lines: nil)
      ProposeEntry.new(@chat).execute(
        description: "Office supplies",
        effective_date: Date.current.to_s,
        lines: lines || lines_default
      )
    end

    def lines_default
      [
        { account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    end
end
