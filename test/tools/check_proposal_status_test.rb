require "test_helper"

class CheckProposalStatusTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Test chat"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "journal_entry",
      version: 1,
      data: {
        "description" => "Gift to girlfriend",
        "entry_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @expense.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "reports a pending proposal as not yet recorded" do
    result = CheckProposalStatus.new(@workspace).execute

    assert_equal 1, result.size
    assert_equal "proposed", result.first[:status]
    assert_nil result.first[:recorded_as_journal_entry_id]
  end

  test "reports a confirmed proposal with its journal entry" do
    draft = build_draft
    assert_nil @proposal.confirm!(draft: draft)

    result = CheckProposalStatus.new(@workspace).execute

    assert_equal "confirmed", result.first[:status]
    assert_equal @proposal.journal_entry.id, result.first[:recorded_as_journal_entry_id]
    assert_equal Date.current.to_s, result.first[:recorded_on]
  end

  test "reports a dismissed proposal as not recorded" do
    @proposal.dismiss!

    result = CheckProposalStatus.new(@workspace).execute

    assert_equal "dismissed", result.first[:status]
    assert_nil result.first[:recorded_as_journal_entry_id]
  end

  test "returns an empty array when there are no proposals" do
    @proposal.destroy!

    assert_equal [], CheckProposalStatus.new(@workspace).execute
  end

  private

  def build_draft
    Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Gift to girlfriend",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "2000" },
        { account_id: @cash.id, side: "credit", amount_naira: "2000" }
      ]
    )
  end
end
