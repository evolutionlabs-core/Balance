require "test_helper"

class JournalEntries::ReversalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @entry = post_journal_entry!(@workspace, debit_account: @groceries, credit_account: @cash, amount_kobo: 2_500_00,
      effective_date: 3.days.ago.to_date, description: "Weekly shop")
  end

  test "renders the reversal form in the modal" do
    get new_journal_entry_reversal_path(@entry)

    assert_response :success
    assert_select "turbo-frame#modal form[action=?]", journal_entry_reversal_path(@entry)
  end

  test "posts a mirrored reversal and leaves the original untouched" do
    assert_difference -> { @ledger.journal_entries.count }, 1 do
      post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: Date.current.iso8601, description: "" } }
    end

    assert_redirected_to journal_entry_path(@entry)

    reversal = @entry.reload.reversal
    assert_equal @ledger, reversal.ledger
    assert_equal @entry, reversal.reverses_entry
    assert_equal Date.current, reversal.effective_date
    assert_equal "Reversal of entry ##{@entry.number}", reversal.description
    assert_equal users(:one), reversal.posted_by
    assert_equal [ "JournalEntry", @entry.id, "reverse" ], [ reversal.source_type, reversal.source_id, reversal.action ]
    assert_equal({ @cash.id => [ 2_500_00, 0 ], @groceries.id => [ 0, 2_500_00 ] },
      reversal.journal_entry_lines.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
    assert_equal({ @groceries.id => [ 2_500_00, 0 ], @cash.id => [ 0, 2_500_00 ] },
      @entry.journal_entry_lines.reload.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
    assert_equal "Weekly shop", @entry.description
  end

  test "a repeated submit does not post a second reversal" do
    post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: Date.current.iso8601 } }

    assert_no_difference -> { @ledger.journal_entries.count } do
      post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: Date.current.iso8601 } }
    end

    assert_redirected_to journal_entry_path(@entry)
  end

  test "rejects a date before the original entry" do
    assert_no_difference -> { @ledger.journal_entries.count } do
      post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: 5.days.ago.to_date.iso8601 } }
    end

    assert_response :unprocessable_content
    assert_select "body", /can.t be before the original entry/
  end

  test "rejects a reversal dated in a closed period" do
    @ledger.close_books!(through: Date.current, actor: users(:one))

    assert_no_difference -> { @ledger.journal_entries.count } do
      post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: Date.current.iso8601 } }
    end

    assert_response :unprocessable_content
    assert_select "body", /Ledger is closed through #{Date.current.iso8601}/
  end

  test "entries posted by documents are corrected from the document instead" do
    sourced = AccountingEngine.post(AccountingEngine::Command.new(
      ledger: @ledger, effective_date: Date.current, source_type: "Expense", source_id: 999, action: "create",
      description: "Fuel", posted_by: users(:one),
      lines: [
        AccountingEngine::Command::Line.new(account: @groceries, debit: 1_000, credit: 0),
        AccountingEngine::Command::Line.new(account: @cash, debit: 0, credit: 1_000)
      ]
    )).entry

    get new_journal_entry_reversal_path(sourced)
    assert_redirected_to journal_entry_path(sourced)

    assert_no_difference -> { @ledger.journal_entries.count } do
      post journal_entry_reversal_path(sourced), params: { reversal: { effective_date: Date.current.iso8601 } }
    end
  end

  test "a reversal cannot itself be reversed here" do
    post journal_entry_reversal_path(@entry), params: { reversal: { effective_date: Date.current.iso8601 } }
    reversal = @entry.reload.reversal

    get new_journal_entry_reversal_path(reversal)

    assert_redirected_to journal_entry_path(reversal)
  end

  test "only opens entries in the current workspace" do
    other_ledger = provision_business_ledger!(workspaces(:bola_shop))
    accounts = other_ledger.accounts.where(base_type: "asset").first(2)
    other = post_journal_entry!(workspaces(:bola_shop), debit_account: accounts.first, credit_account: accounts.last, amount_kobo: 100)

    get new_journal_entry_reversal_path(other)

    assert_response :not_found
  end
end
