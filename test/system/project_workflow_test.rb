require "application_system_test_case"

class ProjectWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(password: "password")
    @workspace = workspaces(:ada_store)
    @bank = @workspace.accounts.create!(name: "Workflow Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @category = @workspace.accounts.create!(name: "Workflow Materials", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
    income = @workspace.accounts.create!(name: "Workflow Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @workspace.update!(default_sales_account: income)
    Account.for_role!(@workspace, :receivable)
    @customer = @workspace.customers.create!(name: "Workflow Customer", customer_type: "business", email: "workflow@example.com")
    sign_in(@user)
  end

  test "navigates project tabs with header preserved across refresh" do
    project = @workspace.projects.create!(customer: @customer, name: "Tab Villa")

    visit project_path(project)
    assert_selector "h1", text: "Tab Villa"
    assert_selector "span[aria-current='page']", text: "Overview"

    within("nav[aria-label='Project sections']") { click_on "Estimates" }
    assert_current_path project_project_estimates_path(project)
    assert_selector "h1", text: "Tab Villa"
    assert_selector "span[aria-current='page']", text: "Estimates"

    visit current_path
    assert_selector "span[aria-current='page']", text: "Estimates"

    within("nav[aria-label='Project sections']") { click_on "Work" }
    assert_current_path project_project_tasks_path(project)

    within("nav[aria-label='Project sections']") { click_on "Activity" }
    assert_current_path project_project_activities_path(project)
    assert_selector "h1", text: "Tab Villa"
  end

  test "edits a project from the index inside the modal frame" do
    project = @workspace.projects.create!(customer: @customer, name: "Modal Edit Villa")
    visit projects_path

    find("a[aria-label='Edit Modal Edit Villa']").click

    assert_selector "#modal", text: "Edit project"
    assert_current_path projects_path

    within("#modal") do
      fill_in "Name", with: "Modal Edit Villa Renamed"
      click_on "Save changes"
    end

    assert_selector "h1", text: "Projects"
    assert_equal "Modal Edit Villa Renamed", project.reload.name
  end

  test "creates and converts a free-form estimate" do
    project = @workspace.projects.create!(customer: @customer, name: "Estimate Villa")
    visit project_project_estimates_path(project)

    click_on "New estimate", match: :first
    assert_selector "p", text: "ESTIMATE"
    fill_in "estimate_line_items_attributes_0_description", with: "Hosting"
    fill_in "estimate_line_items_attributes_0_quantity", with: "12"
    fill_in "estimate_line_items_attributes_0_rate", with: "5000"
    click_on "Save"

    assert_selector "article", text: "Hosting"
    assert_selector "dd", text: "NGN 60,000.00"

    estimate = Estimate.order(:id).last
    assert_selector "a[href='#{project_estimate_path(estimate, format: :pdf)}']", text: "Download"
    click_on "Mark as sent"
    assert_text "Estimate #{estimate.number} sent."
    find("button[aria-label='Client actions']").click
    click_on "Approve manually"
    assert_text "Estimate #{estimate.number} approved."
    click_on "Convert to Invoice"
    assert_current_path %r{\A/invoices/\d+\z}
    assert_selector "article", text: "Hosting"
    invoice = @workspace.invoices.find_by!(estimate: estimate)
    assert_equal 6_000_000, invoice.total_minor
    assert_nil invoice.invoice_lines.sole.service
    assert invoice.draft?
    click_on "Issue invoice"
    within "#modal dialog" do
      assert_no_selector "select"
      click_on "Issue invoice"
    end
    assert invoice.reload.posted?
  end

  test "creates a task then logs time against it from the task row" do
    project = @workspace.projects.create!(customer: @customer, name: "Work Villa")
    visit project_project_tasks_path(project)

    click_on "Add task", match: :first
    assert_selector "#modal", text: "Add task"
    fill_in "Title", with: "Extra wiring"
    within("#modal") { click_on "Add task" }

    assert_selector "td", text: "Extra wiring"

    task = project.reload.tasks.find_by(title: "Extra wiring")
    within("tr", text: "Extra wiring") { click_on "Log time" }
    assert_selector "#modal", text: "Log time"
    assert_selector "#modal select option[selected]", text: "Extra wiring"
    fill_in "Hours", with: "3"
    fill_in "Work performed", with: "Same-day wiring"
    within("#modal") { click_on "Log time" }

    assert_selector "td", text: "Same-day wiring"
    assert_equal task, project.reload.time_entries.last.task
  end

  test "activity lists logged time" do
    project = @workspace.projects.create!(customer: @customer, name: "Activity Villa")
    task = project.tasks.create!(title: "Wiring")
    project.time_entries.create!(task: task, occurred_on: Date.current, hours: 2, description: "Site work")

    visit project_project_activities_path(project)

    assert_selector "li", text: /Site work/
  end

  private
    def sign_in(user)
      visit new_session_path
      fill_in "Email", with: user.email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end
end
