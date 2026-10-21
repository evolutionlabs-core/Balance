require "test_helper"

class JournalEntryDraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
  end

  test "saves an incomplete draft without posting anything" do
    assert_difference -> { @workspace.journal_entry_drafts.count } => 1, -> { JournalEntry.count } => 0 do
      post journal_entry_drafts_path, params: { intent: "draft", entry: { effective_date: "", description: "",
        lines: { "0" => { account_id: @groceries.id, debit: "250.00", credit: "" }, "1" => { account_id: "", debit: "", credit: "" } } } }
    end

    assert_redirected_to journal_entry_drafts_path
    draft = @workspace.journal_entry_drafts.sole
    assert_equal users(:one), draft.user
    assert_nil draft.effective_date
    assert_equal [ { "account_id" => @groceries.id.to_s, "debit" => "250.00", "credit" => "" } ], draft.lines
  end

  test "review saves the draft and shows it without posting" do
    assert_no_difference -> { JournalEntry.count } do
      post journal_entry_drafts_path, params: balanced_params(intent: "review")
    end

    draft = @workspace.journal_entry_drafts.sole
    assert_redirected_to journal_entry_draft_path(draft)

    get journal_entry_draft_path(draft)
    assert_response :success
    assert_select "body", /Ready to post/
    assert_select "form[action=?]", journal_entry_draft_posting_path(draft)
    assert_select "tbody td", text: /Groceries/
  end

  test "review rejects an unbalanced entry with the engine's reason and keeps what was typed" do
    assert_no_difference -> { @workspace.journal_entry_drafts.count } do
      post journal_entry_drafts_path, params: { intent: "review", entry: { effective_date: Date.current.iso8601, description: "Unbalanced",
        lines: { "0" => { account_id: @groceries.id, debit: "1000.00", credit: "" }, "1" => { account_id: @cash.id, debit: "", credit: "500.00" } } } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Total debits (1000.00) must equal total credits (500.00)"
    assert_select "input[name='entry[description]'][value='Unbalanced']"
  end

  test "review reports a malformed amount as a form error" do
    post journal_entry_drafts_path, params: { intent: "review", entry: { effective_date: Date.current.iso8601, description: "Typo",
      lines: { "0" => { account_id: @groceries.id, debit: "1.2.3", credit: "" }, "1" => { account_id: @cash.id, debit: "", credit: "-50" } } } }

    assert_response :unprocessable_content
    assert_includes response.body, "Line 1: enter amounts as positive numbers, like 1,250.00"
  end

  test "posting records the entry through the engine under the draft's key" do
    draft = create_draft

    assert_difference -> { @ledger.journal_entries.count }, 1 do
      post journal_entry_draft_posting_path(draft)
    end

    entry = draft.reload.posted_entry
    assert_redirected_to journal_entry_path(entry)
    assert_equal @ledger, entry.ledger
    assert_equal [ "JournalEntryDraft", draft.id, "create" ], entry.values_at(:source_type, :source_id, :action)
    assert_equal "Manual shop", entry.description
    assert_equal users(:one), entry.posted_by
    assert_equal({ @groceries.id => [ 1_000_00, 0 ], @cash.id => [ 0, 1_000_00 ] },
      entry.journal_entry_lines.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
    assert entry.reversible?
  end

  test "posting twice records one entry" do
    draft = create_draft
    post journal_entry_draft_posting_path(draft)

    assert_no_difference -> { @ledger.journal_entries.count } do
      post journal_entry_draft_posting_path(draft)
    end

    assert_redirected_to journal_entry_path(draft.reload.posted_entry)
  end

  test "a draft whose entry posted but was never linked links on retry instead of posting again" do
    draft = create_draft
    existing = post_with_key!("JournalEntryDraft", draft.id)

    assert_no_difference -> { @ledger.journal_entries.count } do
      assert draft.post!
    end

    assert_equal existing, draft.reload.posted_entry
  end

  test "a draft id that matches an assistant entry's source id still posts its own entry" do
    draft = create_draft
    post_with_key!("Entry", draft.id)

    assert_difference -> { @ledger.journal_entries.count }, 1 do
      post journal_entry_draft_posting_path(draft)
    end

    assert_equal "JournalEntryDraft", draft.reload.posted_entry.source_type
  end

  test "carries the reference and tags from draft to posted entry" do
    post journal_entry_drafts_path, params: balanced_params(intent: "review").deep_merge(entry: { reference: " INV-77 ", tags: "Office, q4 ,office, " })
    draft = @workspace.journal_entry_drafts.sole
    assert_equal [ "INV-77", %w[office q4] ], [ draft.reference, draft.tags ]

    post journal_entry_draft_posting_path(draft)

    entry = draft.reload.posted_entry
    assert_equal "INV-77", entry.reference
    assert_equal %w[office q4], entry.tags

    get journal_entry_path(entry)
    assert_select "dd", text: "INV-77"
    assert_select "a[href=?]", journal_entries_path(tag: "q4"), text: "q4"
  end

  test "entries recorded without a draft keep the Entry source type" do
    form = JournalEntries::ManualEntry.new(workspace: @workspace, effective_date: Date.current, description: "Direct",
      lines: [ { account_id: @groceries.id, debit: "5.00", credit: "" }, { account_id: @cash.id, debit: "", credit: "5.00" } ])

    assert form.record!
    assert_equal [ "Entry", nil, "create" ], form.entry.values_at(:source_type, :source_id, :action)
  end

  test "edits and deletes an unposted draft" do
    draft = create_draft

    get edit_journal_entry_draft_path(draft)
    assert_response :success
    assert_select "form[action=?]", journal_entry_draft_path(draft)

    patch journal_entry_draft_path(draft), params: balanced_params(intent: "draft", description: "Renamed")
    assert_redirected_to journal_entry_drafts_path
    assert_equal "Renamed", draft.reload.description

    assert_difference -> { @workspace.journal_entry_drafts.count }, -1 do
      delete journal_entry_draft_path(draft)
    end
    assert_redirected_to journal_entry_drafts_path
  end

  test "a posted draft is closed to edits and points to its entry" do
    draft = create_draft
    post journal_entry_draft_posting_path(draft)
    entry = draft.reload.posted_entry

    get journal_entry_draft_path(draft)
    assert_redirected_to journal_entry_path(entry)

    patch journal_entry_draft_path(draft), params: balanced_params(intent: "draft", description: "Changed")
    assert_redirected_to journal_entry_path(entry)
    assert_equal "Manual shop", draft.reload.description

    assert_no_difference -> { JournalEntryDraft.count } do
      delete journal_entry_draft_path(draft)
    end
  end

  test "lists unposted drafts and links them from the journal" do
    open_draft = create_draft(description: "Still open")
    posted = create_draft(description: "Already posted")
    post journal_entry_draft_posting_path(posted)

    get journal_entry_drafts_path
    assert_response :success
    assert_select "tr##{dom_id(open_draft)}"
    assert_select "tr##{dom_id(posted)}", count: 0

    get journal_entries_path
    assert_select "a[href=?]", journal_entry_drafts_path, text: "Drafts (1)"
  end

  test "only opens drafts in the current workspace" do
    other = workspaces(:bola_shop).journal_entry_drafts.create!(user: users(:one), description: "Theirs")

    get journal_entry_draft_path(other)
    assert_response :not_found

    post journal_entry_draft_posting_path(other)
    assert_response :not_found
  end

  private
    def balanced_params(intent:, description: "Manual shop")
      { intent: intent, entry: { effective_date: Date.current.iso8601, description: description,
        lines: { "0" => { account_id: @groceries.id, debit: "1000.00", credit: "" }, "1" => { account_id: @cash.id, debit: "", credit: "1000.00" } } } }
    end

    def create_draft(description: "Manual shop")
      draft = @workspace.journal_entry_drafts.build(user: users(:one))
      draft.assign_form(balanced_params(intent: "review", description: description)[:entry])
      draft.save!
      draft
    end

    def post_with_key!(source_type, source_id)
      AccountingEngine.post(AccountingEngine::Command.new(
        ledger: @ledger, effective_date: Date.current, source_type: source_type, source_id: source_id, action: "create",
        description: "Manual shop", posted_by: users(:one),
        lines: [
          AccountingEngine::Command::Line.new(account: @groceries, debit: 1_000_00, credit: 0),
          AccountingEngine::Command::Line.new(account: @cash, debit: 0, credit: 1_000_00)
        ]
      )).entry
    end
end
