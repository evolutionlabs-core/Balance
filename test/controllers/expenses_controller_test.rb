require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @bank = create_account(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @fuel = create_account(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "renders the scoped expense form" do
    get new_expense_path

    assert_response :success
    assert_select "select#expense_payment_account_id option", text: "Checking"
    assert_select "select#expense_expense_lines_attributes_0_account_id option", text: "Fuel"
    assert_select "input[name='expense[expense_lines_attributes][0][amount]']"
    assert_select "input[name='expense[payment_account_id]']", count: 0
    assert_select "input[name='expense[payee]']", count: 0
    assert_select "input[name='expense[reference_number]']", count: 0
    assert_select "input[name='expense[memo]']"
    assert_select "[data-select-menu-search-in-trigger-value='true'] input[role='combobox'][placeholder='Who did you pay to?']"
    assert_select "[data-select-menu-footer-label-value='Add vendor'][data-select-menu-footer-url-value='#{new_contact_path(role: "vendor")}']"
    assert_select "[data-controller='select-menu'][data-select-menu-search-in-trigger-value='true'] input[role='combobox']", count: 4
  end

  test "only offers vendor contacts on the expense form" do
    vendor = @workspace.contacts.create!(name: "Fuel Vendor", contact_kind: "business", email: "vendor@example.com", role_names: %w[vendor])
    customer = @workspace.contacts.create!(name: "Retail Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])

    get new_expense_path

    assert_select "select#expense_payee_contact_id option[value='#{vendor.id}']", text: vendor.name
    assert_select "select#expense_payee_contact_id option[value='#{customer.id}']", count: 0
  end

  test "rejects a customer-only contact as the vendor" do
    customer = @workspace.contacts.create!(name: "Retail Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])
    params = expense_params
    params[:expense][:payee_contact_id] = customer.id

    assert_no_difference("Expense.count") do
      post expenses_path, params: params
    end

    assert_response :unprocessable_content
    assert_match(/Payee contact must be a vendor/, response.body)
  end

  test "does not link to expense reports" do
    get expenses_path

    assert_response :success
    assert_select "a[href='#{expense_report_path}']", count: 0
  end

  test "shows possible duplicates within the review page" do
    vendor = @workspace.contacts.create!(name: "Fuel Station", contact_kind: "business", email: "duplicate@example.com", role_names: %w[vendor])
    params = expense_params
    params[:expense][:payee_contact_id] = vendor.id
    post expenses_path, params: params
    original = @workspace.expenses.order(:id).last

    post expenses_path, params: params
    follow_redirect!

    assert_response :success
    assert_select "[role='alert']", text: /may already be recorded/
    assert_select "a[href='#{expense_path(original)}']", text: "View expense"
    assert_nil flash[:alert]
  end

  test "creates a draft for review" do
    payee = @workspace.contacts.create!(name: "Fuel Station", contact_kind: "business", email: "fuel@example.com", role_names: %w[vendor])
    params = expense_params
    params[:expense][:payee_contact_id] = payee.id
    params[:expense][:memo] = "Generator fuel"

    assert_difference("Expense.count", 1) do
      post expenses_path, params: params
    end

    expense = @workspace.expenses.order(:id).last
    assert_redirected_to expense_path(expense)
    assert expense.draft?
    assert_nil expense.journal_entry
    assert_equal payee, expense.payee_contact
    assert_equal "Generator fuel", expense.memo
  end

  test "shows a validation error for a malformed amount" do
    params = expense_params
    params[:expense][:expense_lines_attributes]["0"][:amount] = "3ooo"

    assert_no_difference("Expense.count") do
      post expenses_path, params: params
    end

    assert_response :unprocessable_content
    assert_match(/Expense lines amount must be a valid number/, response.body)
    assert_select "input[name='expense[expense_lines_attributes][0][amount]'][value='3ooo']"
  end

  test "posts the reviewed expense" do
    post expenses_path, params: expense_params
    expense = @workspace.expenses.order(:id).last

    assert_difference("JournalEntry.count", 1) do
      post expense_posting_path(expense)
    end

    assert_redirected_to expenses_path
    assert expense.reload.posted?
  end

  test "updates a draft before posting" do
    post expenses_path, params: expense_params
    expense = @workspace.expenses.order(:id).last

    patch expense_path(expense), params: {
      expense: {
        payment_date: Date.current,
        payment_account_id: @bank.id,
        expense_lines_attributes: {
          "0" => {
            id: expense.expense_lines.first.id,
            account_id: @fuel.id,
            description: "Diesel",
            amount: "45000.00",
            position: 0
          }
        }
      }
    }

    assert_redirected_to expense_path(expense)
    assert_equal "Diesel", expense.expense_lines.first.reload.description
    assert_equal 4_500_000, expense.expense_lines.first.amount_kobo
  end

  test "does not edit a posted expense" do
    post expenses_path, params: expense_params
    expense = @workspace.expenses.order(:id).last
    assert expense.post.success?

    get edit_expense_path(expense)

    assert_response :not_found
  end

  test "lists expenses in the current workspace" do
    expense = @workspace.expenses.create!(
      payment_date: Date.current,
      payment_account: @bank,
      expense_lines_attributes: [ { account: @fuel, description: "Fuel", amount_kobo: 4_000_000, position: 0 } ]
    )

    get expenses_path

    assert_response :success
    assert_select "tr##{dom_id(expense)}", text: /Fuel/
    assert_select "tr##{dom_id(expense)}", text: /Checking/
    assert_select "tr##{dom_id(expense)} a[href='#{expense_path(expense)}']", minimum: 1
    assert_select "tr##{dom_id(expense)} a[href='#{edit_expense_path(expense)}']", text: "Edit"
  end

  test "lists posted expenses as view only" do
    expense = @workspace.expenses.create!(
      payment_date: Date.current,
      payment_account: @bank,
      expense_lines_attributes: [ { account: @fuel, description: "Fuel", amount_kobo: 4_000_000, position: 0 } ]
    )
    assert expense.post.success?

    get expenses_path

    assert_response :success
    assert_select "tr##{dom_id(expense)} a[href='#{expense_path(expense)}']", text: "View"
    assert_select "tr##{dom_id(expense)} a[href='#{edit_expense_path(expense)}']", count: 0
  end

  test "cannot access another workspace expense" do
    other_workspace = workspaces(:bola_shop)
    other_bank = other_workspace.accounts.create!(name: "Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    other_category = other_workspace.accounts.create!(name: "Food", base_type: "expense", account_type: "Personal Outflows", detail_type: "Living & Daily Needs")
    expense = other_workspace.expenses.create!(
      payment_date: Date.current,
      payment_account: other_bank,
      expense_lines_attributes: [ { account: other_category, description: "Food", amount_kobo: 1_000, position: 0 } ]
    )

    get expense_path(expense)

    assert_response :not_found
  end

  private
    def create_account(**attributes)
      @workspace.accounts.create!(attributes)
    end

    def expense_params
      {
        expense: {
          payment_date: Date.current,
          payment_account_id: @bank.id,
          expense_lines_attributes: {
            "0" => { account_id: @fuel.id, description: "Fuel", amount: "40000.00", position: 0 }
          }
        }
      }
    end
end
