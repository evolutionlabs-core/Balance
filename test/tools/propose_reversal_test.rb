require "test_helper"

class ProposeReversalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(workspace: @workspace, model: ruby_llm_models(:default), title: "Test chat")
    @entry = record_entry(description: "Cash spent on supplies", amount_kobo: 250_000)
  end

  test "returns an exact entry confirmation without preparing or posting a reversal" do
    assert_no_difference [ "JournalEntry.count", "Proposal.count" ] do
      result = ProposeReversal.new(@chat).execute(entry_id: @entry.id)

      assert result[:proposal]
      assert_equal "reversal_confirmation", result[:proposed_action]
      assert_equal @entry.id, result.dig(:entry_data, "source_journal_entry_id")
      assert_equal @entry.description, result.dig(:entry_data, "description")
      assert_equal @entry.effective_date.iso8601, result.dig(:entry_data, "effective_date")
      assert_equal %w[debit credit], result.dig(:entry_data, "lines").pluck("side")
      assert_equal [ @groceries.name, @cash.name ], result.dig(:entry_data, "lines").pluck("account_name")
      refute result[:entry_data].key?("reverses_journal_entry_id")
    end
  end

  test "prose and earlier approvals do not bypass the confirmation card" do
    @chat.llm_messages.create!(role: "assistant", content: "Entry ID #{@entry.id}. Please confirm yes if correct.")
    @chat.llm_messages.create!(role: "user", content: "yes")

    result = ProposeReversal.new(@chat).execute(entry_id: @entry.id)

    assert_equal "reversal_confirmation", result[:proposed_action]
  end

  test "keeps an explicit original-date choice for the confirmation" do
    result = ProposeReversal.new(@chat).execute(entry_id: @entry.id, use_original_date: true)

    assert result.dig(:entry_data, "use_original_date")
  end

  test "rejects another workspace entry" do
    workspaces(:bola_shop).provision_ledger!
    other_chat = Llm::Chat.create!(workspace: workspaces(:bola_shop), model: @chat.model, title: "Other")

    result = ProposeReversal.new(other_chat).execute(entry_id: @entry.id)

    assert_equal "That entry does not exist in this workspace.", result[:error]
  end

  test "rejects an already reversed entry" do
    record_entry(description: "Reversal", amount_kobo: 250_000, reverses_journal_entry_id: @entry.id)

    result = ProposeReversal.new(@chat).execute(entry_id: @entry.id)

    assert_equal "That entry has already been reversed.", result[:error]
  end

  test "rejects an entry that is itself a reversal" do
    reversal_entry = record_entry(description: "Reversal", amount_kobo: 250_000, reverses_journal_entry_id: @entry.id)

    result = ProposeReversal.new(@chat).execute(entry_id: reversal_entry.id)

    assert_equal "That entry is itself a reversal.", result[:error]
  end

  private
    def record_entry(description:, amount_kobo:, reverses_journal_entry_id: nil)
      reversal = reverses_journal_entry_id.present?
      original = reverses_journal_entry_id && JournalEntry.find(reverses_journal_entry_id)
      data = {
        "description" => description,
        "effective_date" => Date.current.iso8601,
        "lines" => reversal ? [
          { "account_id" => @cash.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "account_id" => @groceries.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ] : [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ]
      }
      data["reverses_journal_entry_id"] = original.id if reversal
      proposal = @chat.proposals.create!(
        workspace: @workspace,
        proposal_type: "entry",
        version: (@chat.proposals.maximum(:version) || 0) + 1,
        data: data
      )
      assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: proposal.data))
      proposal.reload.journal_entry
    end
end
