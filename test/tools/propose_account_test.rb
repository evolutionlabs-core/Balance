require "test_helper"

class ProposeAccountTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @tool = ProposeAccount.new(stub_llm_chat(workspace: @workspace, prompt: "I paid rent"))
  end

  test "returns a reviewable proposal without creating an account" do
    assert_no_difference "LedgerAccount.count" do
      @result = propose_rent
    end

    assert_instance_of RubyLLM::Tool::Halt, @result
    assert @result.content[:proposal]
    assert_equal "account_creation", @result.content[:proposed_action]
    assert_equal "Rent & Housing", @result.content.dig(:entry_data, "accounts", 0, "name")
    assert_equal "housing", @result.content.dig(:entry_data, "accounts", 0, "subtype")
  end

  test "validates the ledger taxonomy before presenting a proposal" do
    result = propose_rent(subtype: "Made up")

    refute result[:proposal]
    assert_includes result[:error], "must have a valid subtype"
  end

  test "does not propose an account that already exists in the ledger chart" do
    @ledger.ledger_accounts.create!(
      name: "Rent & Housing",
      base_type: "expense",
      subtype: "housing",
      code: "9510",
      created_by: "admin"
    )

    result = propose_rent

    refute result[:proposal]
    assert_includes result[:error], "These accounts already exist: Rent & Housing"
  end

  private
    def propose_rent(**overrides)
      @tool.execute(
        reason: "Rent needs its own expense account.",
        accounts: [ rent_account(**overrides) ]
      )
    end

    def rent_account(**overrides)
      {
        name: "Rent & Housing",
        base_type: "expense",
        subtype: "housing",
        **overrides
      }
    end
end
