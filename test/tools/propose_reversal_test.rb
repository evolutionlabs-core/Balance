require "test_helper"

class ProposeReversalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @entry = post_journal_entry!(@workspace, debit_account: @expense, credit_account: @cash, amount_kobo: 250_000)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Test chat"
    )
  end

  test "returns an exact entry confirmation without preparing or posting a reversal" do
    assert_no_difference [ "JournalEntry.count", "Proposal.count" ] do
      result = ProposeReversal.new(@chat).execute(entry_id: @entry.id)

      assert result[:proposal]
      assert_equal "reversal_confirmation", result[:proposed_action]
      assert_equal @entry.id, result.dig(:entry_data, "source_entry_id")
      assert_equal @entry.description, result.dig(:entry_data, "description")
      assert_equal @entry.entry_date.iso8601, result.dig(:entry_data, "entry_date")
      assert_equal %w[debit credit], result.dig(:entry_data, "lines").pluck("side")
      assert_equal [ @expense.name, @cash.name ], result.dig(:entry_data, "lines").pluck("account_name")
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
    other_chat = Llm::Chat.create!(workspace: workspaces(:bola_shop), model: @chat.model, title: "Other")

    result = ProposeReversal.new(other_chat).execute(entry_id: @entry.id)

    assert_equal "That journal entry does not exist in this workspace.", result[:error]
  end

  test "rejects an already reversed entry" do
    @entry.reverse!

    result = ProposeReversal.new(@chat).execute(entry_id: @entry.id)

    assert_equal "That journal entry has already been reversed.", result[:error]
  end

  test "rejects an entry that is itself a reversal" do
    reversal = @entry.reverse!

    result = ProposeReversal.new(@chat).execute(entry_id: reversal.id)

    assert_equal "That entry is itself a reversal.", result[:error]
  end
end
