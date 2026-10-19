require "test_helper"

class ConfirmProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Confirmation test"),
      title: "Confirmation test"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "entry",
      version: 1,
      data: {
        "description" => "Cash expense",
        "effective_date" => Date.current.iso8601,
        "lines" => [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "records the pending entry proposal exactly once" do
    @chat.llm_messages.create!(role: "user", content: "Approve it")
    tool = ConfirmProposal.new(@chat)

    assert_difference "JournalEntry.count", 1 do
      result = tool.execute
      assert_equal "confirmed", result[:status]
      assert_equal @proposal.id, result[:proposal_id]
    end

    assert_no_difference "JournalEntry.count" do
      result = tool.execute
      assert result[:already_recorded]
      assert_equal @proposal.reload.journal_entry_id, result[:journal_entry_id]
    end
  end

  test "refuses to post without explicit approval" do
    @chat.llm_messages.create!(role: "user", content: "Can you explain this proposal?")

    assert_no_difference "JournalEntry.count" do
      result = ConfirmProposal.new(@chat).execute
      assert_includes result[:error], "not been explicitly approved"
    end
  end

  test "does not mistake a polite edit request for approval" do
    @chat.llm_messages.create!(role: "user", content: "Please change the amount to ₦3,000")

    assert_no_difference "JournalEntry.count" do
      result = ConfirmProposal.new(@chat).execute
      assert_includes result[:error], "not been explicitly approved"
    end
  end

  test "does not post when an affirmative reply also requests a correction" do
    @chat.llm_messages.create!(role: "user", content: "Yes, but change the account first")

    assert_no_difference "JournalEntry.count" do
      result = ConfirmProposal.new(@chat).execute
      assert_includes result[:error], "not been explicitly approved"
    end
  end

  test "accepts a concise natural approval" do
    @chat.llm_messages.create!(role: "user", content: "Yes, please record it.")

    assert_difference "JournalEntry.count", 1 do
      assert_equal "confirmed", ConfirmProposal.new(@chat).execute[:status]
    end
  end

  test "does not confirm an account proposal" do
    @proposal.destroy!
    @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: { "reason" => "Track rent", "accounts" => [] }
    )

    result = ConfirmProposal.new(@chat).execute

    assert_includes result[:error], "There is no entry proposal awaiting approval"
  end

  test "never posts a reversal proposal through chat confirmation" do
    @proposal.update!(data: @proposal.data.merge("reverses_journal_entry_id" => 125))
    @chat.llm_messages.create!(role: "user", content: "Yes, approve it")

    assert_no_difference "JournalEntry.count" do
      result = ConfirmProposal.new(@chat).execute
      assert_includes result[:error], "cannot be recorded through chat"
    end

    assert_equal "proposed", @proposal.reload.status
  end

  test "a reversal selection cannot approve an older entry proposal" do
    @chat.proposals.create!(workspace: @workspace, proposal_type: "reversal_confirmation", data: { "source_journal_entry_id" => 125 })
    @chat.llm_messages.create!(role: "user", content: "yes")

    assert_no_difference "JournalEntry.count" do
      result = ConfirmProposal.new(@chat).execute
      assert_includes result[:error], "reversal confirmation card"
    end
    assert_equal "proposed", @proposal.reload.status
  end
end
