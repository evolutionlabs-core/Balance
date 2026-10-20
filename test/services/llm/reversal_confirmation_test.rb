require "test_helper"

class Llm::ReversalConfirmationTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Reversal test"
    )
    @entry = record_entry(description: "Original payment", amount_kobo: 150_000)
    @confirmation = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "reversal_confirmation",
      data: Llm::ReversalConfirmation.entry_data(@entry)
    )
  end

  test "confirmation prepares an exact mirror but does not post" do
    assert_no_difference "JournalEntry.count" do
      @result = Llm::ReversalConfirmation.new(@confirmation).confirm
    end

    assert_empty @result.errors
    assert @result.proposal.pending?
    assert_equal Date.current.iso8601, @result.proposal.data.fetch("effective_date")
    assert_equal @entry.id, @result.proposal.data.fetch("reverses_journal_entry_id")

    draft = Llm::EntryProposal.new(workspace: @workspace, data: @result.proposal.data)
    assert draft.valid?, draft.errors.join(", ")
  end

  test "only an explicit original date choice uses the source date" do
    @confirmation.update!(data: @confirmation.data.merge("use_original_date" => true))

    result = Llm::ReversalConfirmation.new(@confirmation).confirm

    assert_equal @entry.effective_date.iso8601, result.proposal.data.fetch("effective_date")
  end

  test "a repeated selection approval reuses the same proposal and never posts" do
    first = Llm::ReversalConfirmation.new(@confirmation).confirm

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      repeated = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert_equal first.proposal.id, repeated.proposal.id
    end
  end

  test "an entry reversed while the card was awaiting approval is rejected" do
    reversal_data = {
      "description" => "Reversal of entry ##{@entry.id}: #{@entry.description}",
      "effective_date" => Date.current.iso8601,
      "reverses_journal_entry_id" => @entry.id,
      "lines" => [
        { "account_id" => @cash.id, "side" => "debit", "amount_kobo" => 150_000 },
        { "account_id" => @groceries.id, "side" => "credit", "amount_kobo" => 150_000 }
      ]
    }
    proposal = @chat.proposals.create!(workspace: @workspace, proposal_type: "entry", version: 2, data: reversal_data)
    assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: reversal_data))

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      result = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert result.errors.any? { |error| error.include?("has already been reversed") }
    end
    assert @confirmation.reload.pending?
  end

  test "a source entry must still belong to the confirmation workspace" do
    @confirmation.update!(data: @confirmation.data.merge("source_journal_entry_id" => -1))

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      result = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert_equal [ "That entry does not exist in this workspace." ], result.errors
    end
  end

  private
    def record_entry(description:, amount_kobo: 150_000)
      data = {
        "description" => description,
        "effective_date" => (Date.current - 2.days).iso8601,
        "lines" => [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ]
      }
      proposal = @chat.proposals.create!(workspace: @workspace, proposal_type: "entry", version: 1, data: data)
      assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: proposal.data))
      proposal.reload.journal_entry
    end
end
