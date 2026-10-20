require "test_helper"

class ProposeAccountTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @tool = ProposeAccount.new(stub_llm_chat(workspace: @workspace, prompt: "I paid rent"))
  end

  test "returns a reviewable proposal without creating an account" do
    assert_no_difference "Account.count" do
      @result = propose_rent
    end

    assert @result[:proposal]
    assert_equal "account_creation", @result[:proposed_action]
    assert_equal "Rent & Housing", @result.dig(:entry_data, "accounts", 0, "name")
  end

  test "validates the workspace taxonomy before presenting a proposal" do
    result = propose_rent(detail_type: "Made up")

    refute result[:proposal]
    assert_includes result[:error], "Detail type is not valid"
  end

  test "does not propose an account that already exists" do
    Account.create!(
      workspace: @workspace,
      name: "Rent & Housing",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Housing & Utilities"
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
      account_type: "Personal Outflows",
      detail_type: "Housing & Utilities",
      **overrides
    }
  end
end
