require "test_helper"

class Projects::InvoicesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Invoice Tab Customer", customer_type: "business", email: "invoicetabs@example.com")
    @project = @workspace.projects.create!(customer: @customer, name: "Invoice Tab Villa")
  end

  test "lists only the project invoices with the invoices tab active" do
    project_invoice = @workspace.invoices.create!(
      user: @user, customer: @customer, project: @project,
      issue_date: Date.current, due_date: Date.current + 15.days
    )
    @workspace.invoices.create!(user: @user, customer: @customer, issue_date: Date.current)

    get project_project_invoices_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Invoices"
    assert_select "td", text: project_invoice.invoice_number
    assert_select "table tbody tr", count: 1
  end

  test "renders the empty state without project invoices" do
    get project_project_invoices_path(@project)

    assert_response :success
    assert_select "h2", text: "No invoices yet"
  end

  test "scopes project invoices to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "single", email: "o@example.com")
    other_project = other_workspace.projects.create!(customer: other_customer, name: "Other project")

    get project_project_invoices_path(other_project)

    assert_response :not_found
  end
end
