require "test_helper"

class Llm::ReversalConfirmationTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @entry = @workspace.journal_entries.create!(
      description: "Original payment",
      entry_date: Date.current - 2.days,
      journal_entry_lines_attributes: [
        { account: @expense, debit_kobo: 150_000 },
        { account: @cash, credit_kobo: 150_000 }
      ]
    )
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Reversal test"
    )
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
    assert_equal Date.current.iso8601, @result.proposal.entry_date
    assert_equal @entry.id, @result.proposal.data.fetch("reverses_journal_entry_id")
    draft = Llm::JournalEntryProposal.new(workspace: @workspace, data: @result.proposal.data)
    assert draft.valid?
    assert_empty Accounting::Engine.reversal_errors(original_lines: @entry.journal_entry_lines, reversal_lines: draft.entry.journal_entry_lines)
  end

  test "only an explicit original date choice uses the source date" do
    @confirmation.update!(data: @confirmation.data.merge("use_original_date" => true))

    result = Llm::ReversalConfirmation.new(@confirmation).confirm

    assert_equal @entry.entry_date.iso8601, result.proposal.entry_date
  end

  test "a repeated selection approval reuses the same proposal and never posts" do
    first = Llm::ReversalConfirmation.new(@confirmation).confirm

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      repeated = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert_equal first.proposal.id, repeated.proposal.id
    end
  end

  test "an entry reversed while the card was awaiting approval is rejected" do
    @entry.reverse!

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      result = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert result.errors.any? { |error| error.include?("has already been reversed") }
    end
    assert @confirmation.reload.pending?
  end

  test "a source entry must still belong to the confirmation workspace" do
    @confirmation.update!(data: @confirmation.data.merge("source_entry_id" => -1))

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      result = Llm::ReversalConfirmation.new(@confirmation).confirm
      assert_equal [ "That journal entry does not exist in this workspace." ], result.errors
    end
  end
end
