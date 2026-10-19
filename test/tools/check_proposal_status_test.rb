require "test_helper"

class CheckProposalStatusTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
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
        "description" => "Gift to girlfriend",
        "effective_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "reports a pending proposal as not yet recorded" do
    result = CheckProposalStatus.new(@workspace).execute

    assert_equal 1, result.size
    assert_equal "proposed", result.first[:status]
    assert_nil result.first[:recorded_as_entry_id]
  end

  test "reports a confirmed proposal with its journal entry" do
    draft = build_draft
    assert_nil @proposal.confirm!(draft: draft)

    result = CheckProposalStatus.new(@workspace).execute

    assert_equal "confirmed", result.first[:status]
    assert_equal @proposal.journal_entry.id, result.first[:recorded_as_entry_id]
    assert_equal Date.current.to_s, result.first[:recorded_on]
  end

  test "reports a dismissed proposal as not recorded" do
    @proposal.dismiss!

    result = CheckProposalStatus.new(@workspace).execute

    assert_equal "dismissed", result.first[:status]
    assert_nil result.first[:recorded_as_entry_id]
  end

  test "returns an empty array when there are no proposals" do
    @proposal.destroy!

    assert_equal [], CheckProposalStatus.new(@workspace).execute
  end

  private
    def build_draft
      Llm::EntryProposal.from_tool(
        workspace: @workspace,
        description: "Gift to girlfriend",
        effective_date: Date.current.to_s,
        lines: [
          { account_id: @groceries.id, side: "debit", amount_naira: "2000" },
          { account_id: @cash.id, side: "credit", amount_naira: "2000" }
        ]
      )
    end
end
