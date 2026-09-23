require "test_helper"

class Projects::ProjectTabsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Tab Customer", customer_type: "business", email: "tabs@example.com")
    @project = @workspace.projects.create!(
      customer: @customer, name: "Tab Project", description: "Fit-out works"
    )
    @bank = @workspace.accounts.create!(name: "Tab Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @category = @workspace.accounts.create!(name: "Tab Materials", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "index opens edit inside the modal frame" do
    get projects_path

    assert_response :success
    assert_select "a[data-turbo-frame='modal'][href=?]", edit_project_path(@project), text: "Edit"
  end

  test "overview shows budget without record tables or history" do
    get project_path(@project)

    assert_response :success
    assert_select "h1", text: "Tab Project"
    assert_select "a[href=?]", customer_path(@customer), text: @customer.name
    assert_select "h2", text: "Budget"
    assert_select "h2", text: "History", count: 0
    assert_select "h2", text: "Scope (estimates / BOQ)", count: 0
    assert_select "h2", text: "Billing (invoices & payments)", count: 0
    assert_select "table", count: 0
  end

  test "overview offers set budget when none exists" do
    get project_path(@project)

    assert_select "a[data-turbo-frame='modal']", text: "Set budget"
    assert_select "dt", text: "Remaining budget", count: 0
  end

  test "overview shows the budget when set" do
    @project.update!(cost_budget_kobo: 1_000_000)

    get project_path(@project)

    assert_select "dt", text: "Cost budget"
    assert_select "a", text: "Set budget", count: 0
  end

  test "activity tab lists logged time" do
    task = @project.tasks.create!(title: "Wiring")
    @project.time_entries.create!(task: task, occurred_on: Date.current, hours: 2, description: "Site work")

    get project_project_activities_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Activity"
    assert_select "li", text: /Site work/
  end

  test "project invoice creation redirects to the canonical preview" do
    post invoices_path, params: {
      invoice: {
        customer_id: @customer.id,
        issue_date: Date.current.to_s, due_date: (Date.current + 7.days).to_s, currency_code: "NGN",
        invoice_lines_attributes: {
          "0" => { description: "Blocks", quantity: "2", rate_minor: "1000" }
        }
      }
    }

    assert_redirected_to invoice_path(Invoice.order(:id).last)
  end
end
