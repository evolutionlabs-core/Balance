require "test_helper"

class ProposeEntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")
    @model = Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model")
    @chat = stub_llm_chat(workspace: @workspace, prompt: "Paid ₦2,500 cash for supplies")
  end

  test "proposes a balanced entry using existing ledger account IDs" do
    result = execute_tool
    result = result.content

    assert result[:proposal]
    assert_equal "entry", result[:proposed_action]
    assert_equal [ @groceries.id, @cash.id ], result.dig(:entry_data, "lines").pluck("ledger_account_id")
  end

  test "rejects a missing account ID instead of bypassing account approval" do
    result = execute_tool(lines: [
      { side: "debit", amount_naira: "2500" },
      { ledger_account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Line 1: choose an account in this workspace"
  end

  test "rejects an account from another workspace" do
    other_ledger = workspaces(:bola_shop).provision_ledger!(template: "standard_sme")
    foreign_bank = other_ledger.ledger_accounts.find_by!(name: "Bank")
    result = execute_tool(lines: [
      { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
      { ledger_account_id: foreign_bank.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Line 2: choose an account in this workspace"
  end

  test "rejects an unbalanced entry" do
    result = execute_tool(lines: [
      { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
      { ledger_account_id: @cash.id, side: "credit", amount_naira: "2000" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Total debits (2500.00) must equal total credits (2000.00)"
  end

  test "requires every account created for the resumed transaction" do
    tax = @ledger.ledger_accounts.create!(name: "Tax Expense", base_type: "expense", subtype: "other_expense", code: "9510", created_by: "admin")
    chat = Llm::Chat.create!(workspace: @workspace, llm_model: @model, title: "Resumed transaction")
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
        { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_includes result[:error], "Tax Expense (id #{tax.id})"

    corrected = ProposeEntry.new(chat).execute(
      description: "Salary with tax",
      effective_date: Date.current.to_s,
      lines: [
        { "ledger_account_id" => @groceries.id, "side" => "debit", "amount_naira" => "2000" },
        { "ledger_account_id" => tax.id, "side" => "debit", "amount_naira" => "500" },
        { "ledger_account_id" => @cash.id, "side" => "credit", "amount_naira" => "2500" }
      ]
    )

    assert_instance_of RubyLLM::Tool::Halt, corrected
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
        { ledger_account_id: @groceries.id, side: "debit", amount_naira: "2500" },
        { ledger_account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    end
end
