require "test_helper"

class EntryTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @entry = AccountingEngine.post(AccountingEngine::Command.new(
      ledger: @ledger, effective_date: 3.days.ago.to_date, source_type: "Entry", action: "create", description: "Weekly shop",
      tags: %w[food], posted_by: users(:one),
      lines: [
        AccountingEngine::Command::Line.new(account: @groceries, debit: 12_500, credit: 0),
        AccountingEngine::Command::Line.new(account: @cash, debit: 0, credit: 12_500)
      ]
    )).entry
  end

  test "saves a manual entry as a template" do
    get journal_entry_path(@entry)
    assert_select "a[href=?]", new_journal_entry_template_path(@entry), text: "Save as template"

    get new_journal_entry_template_path(@entry)
    assert_select "input[name='entry_template[name]'][value='Weekly shop']"

    assert_difference -> { @workspace.entry_templates.count }, 1 do
      post journal_entry_template_path(@entry), params: { entry_template: { name: "Groceries run" } }
    end

    template = @workspace.entry_templates.sole
    assert_equal [ "Groceries run", "Weekly shop", %w[food], users(:one) ], [ template.name, template.description, template.tags, template.user ]
    assert_equal [
      { "account_id" => @groceries.id.to_s, "debit" => "125.00", "credit" => "" },
      { "account_id" => @cash.id.to_s, "debit" => "", "credit" => "125.00" }
    ], template.lines
  end

  test "names are unique per workspace" do
    post journal_entry_template_path(@entry), params: { entry_template: { name: "Groceries run" } }

    assert_no_difference -> { EntryTemplate.count } do
      post journal_entry_template_path(@entry), params: { entry_template: { name: "groceries RUN" } }
    end

    assert_response :unprocessable_content
  end

  test "document entries and reversals can't become templates" do
    reversal = AccountingEngine.reverse(@entry, on: Date.current, source_type: "JournalEntry", source_id: @entry.id).entry

    get new_journal_entry_template_path(reversal)

    assert_redirected_to journal_entry_path(reversal)
  end

  test "using a template opens a prefilled entry for today" do
    template = EntryTemplate.from_entry(@entry, user: users(:one), name: "Groceries run")
    template.save!

    get entry_templates_path
    assert_select "a[href=?]", new_journal_entry_path(template_id: template.id), text: "Use"

    get new_journal_entry_path(template_id: template.id)

    assert_response :success
    assert_select "input[name='entry[description]'][value='Weekly shop']"
    assert_select "input[name='entry[tags]'][value='food']"
    assert_select "input[name='entry[effective_date]'][value=?]", Date.current.iso8601
    assert_select "select[name='entry[lines][0][account_id]'] option[selected][value=?]", @groceries.id.to_s
    assert_select "input[name='entry[lines][0][debit]'][value='125.00']"
    assert_select "input[name='entry[lines][1][credit]'][value='125.00']"
    assert_no_difference -> { JournalEntryDraft.count } do
      get new_journal_entry_path(template_id: template.id)
    end
  end

  test "deletes a template" do
    template = EntryTemplate.from_entry(@entry, user: users(:one), name: "Groceries run")
    template.save!

    assert_difference -> { EntryTemplate.count }, -1 do
      delete entry_template_path(template)
    end
    assert_redirected_to entry_templates_path
  end

  test "index shows 20 templates per page" do
    templates = (1..21).map { |number| create_template(format("Season ticket %02d", number)) }

    get entry_templates_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{entry_templates_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get entry_templates_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tr##{dom_id(templates.last)}"
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index shows pagination with both directions disabled when every template fits on one page" do
    create_template("Season ticket")

    get entry_templates_path

    assert_select "nav[aria-label=Pagination]", text: /\A\s*1–/ do
      assert_select "span[aria-disabled=true]", text: "Previous"
      assert_select "span[aria-disabled=true]", text: "Next"
      assert_select "a", count: 0
    end
  end

  test "templates stay in their workspace" do
    other = workspaces(:bola_shop).entry_templates.create!(user: users(:one), name: "Theirs",
      lines: [ { "account_id" => "1", "debit" => "1.00", "credit" => "" }, { "account_id" => "2", "debit" => "", "credit" => "1.00" } ])

    get new_journal_entry_path(template_id: other.id)
    assert_response :not_found

    delete entry_template_path(other)
    assert_response :not_found
  end

  private
    def create_template(name)
      @workspace.entry_templates.create!(user: users(:one), name: name,
        lines: [ { "account_id" => @groceries.id.to_s, "debit" => "125.00", "credit" => "" }, { "account_id" => @cash.id.to_s, "debit" => "", "credit" => "125.00" } ])
    end
end
