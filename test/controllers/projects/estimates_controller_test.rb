require "test_helper"

class Projects::EstimatesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Estimate Customer", customer_type: "business", email: "estimate@example.com")
    @project = @workspace.projects.create!(customer: @customer, name: "Estimate Villa")
    @income_account = @workspace.accounts.create!(name: "Estimate Service Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @service = @workspace.services.create!(name: "Hosting", income_account: @income_account)
  end

  test "show downloads the estimate as a PDF" do
    estimate = @project.estimates.create!(
      workspace: @workspace, user: @user, customer: @customer,
      line_items_attributes: { "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" } }
    )
    get project_estimate_path(estimate, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment;.*estimate-#{estimate.id}\.pdf/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
    assert estimate.reload.draft?
  end

  test "show offers mark as sent through a form" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)
    get project_estimate_path(estimate)

    assert_response :success
    assert_select "form[action=?]", project_estimate_delivery_path(estimate)
  end

  test "show offers only the actions allowed from the current status" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    get project_estimate_path(estimate)
    assert_select "form[action=?]", project_estimate_delivery_path(estimate), count: 1
    assert_select "form[action=?]", project_estimate_approval_path(estimate), count: 0
    assert_select "form[action=?]", project_estimate_conversion_path(estimate), count: 0

    estimate.send_to_client!
    get project_estimate_path(estimate)
    assert_select "form[action=?]", project_estimate_delivery_path(estimate), count: 0
    assert_select "form[action=?]", project_estimate_approval_path(estimate), count: 1
    assert_select "form[action=?]", project_estimate_decline_path(estimate), count: 1
    assert_select "form[action=?]", project_estimate_conversion_path(estimate), count: 0

    estimate.approve!
    get project_estimate_path(estimate)
    assert_select "form[action=?]", project_estimate_approval_path(estimate), count: 0
    assert_select "form[action=?]", project_estimate_conversion_path(estimate), count: 1
  end

  test "lists estimates with status on the tab" do
    @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    get project_project_estimates_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Estimates"
    assert_select "td", text: /EST-/
    estimate = @project.estimates.last
    assert_select "button[aria-label=?]", "Actions for #{estimate.number}"
    assert_select "a[href=?]", edit_project_estimate_path(estimate), text: "Edit"
  end

  test "renders the full-page editor for new and edit" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    get new_project_project_estimate_path(@project)
    assert_response :success
    assert_select "p", text: "ESTIMATE"
    assert_select "tbody#estimate_lines tr", minimum: 2
    assert_select "nav[aria-label='Estimate views']", count: 0
    assert_select "th", text: "Rate (NGN)", count: 0
    assert_select "p", text: /Add everything the client should approve/, count: 0
    assert_select "a", text: "Edit company"
    assert_select "select[name*='[service_id]'][required]", count: 0

    get edit_project_estimate_path(estimate)
    assert_response :success
    assert_select "p", text: "ESTIMATE"
  end

  test "line item controls return turbo streams without persisting an estimate" do
    headers = { Accept: "text/vnd.turbo-stream.html" }
    attributes = { estimate: { currency_code: "NGN", line_items_attributes: {
      "0" => { service_id: @service.id, description: "First", quantity: 2, rate: 150 },
      "123456789" => { service_id: @service.id, description: "Added", quantity: 1, rate: 50 }
    } } }

    assert_no_difference "Estimate.count" do
      get new_project_project_estimate_line_path(@project), headers: headers
      assert_response :success
      assert_select "turbo-stream[action='append'][target='estimate_lines']"

      post project_project_estimate_calculation_path(@project), params: attributes, headers: headers
      assert_response :success
      assert_select "turbo-stream[target='estimate_total'] template", text: "NGN 350.00"

      delete project_project_estimate_line_path(@project, "0"), params: attributes, headers: headers
      assert_response :success
      assert_select "turbo-stream[action='remove'][target='new_estimate_line_0']"
      assert_select "turbo-stream[target='estimate_total'] template", text: "NGN 50.00"
    end
  end

  test "preview shows the estimate without project details or navigation" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    get project_estimate_path(estimate)

    assert_response :success
    assert_select "p", text: "ESTIMATE"
    assert_select "nav[aria-label='Project sections']", count: 0
    assert_select "nav[aria-label='Estimate views']", count: 0
    assert_select "h1", text: @project.name, count: 0
    assert_select "a[href=?]", edit_project_estimate_path(estimate), text: "Edit"
  end

  test "creates an estimate with lines and billing snapshot" do
    assert_difference("Estimate.count", 1) do
      post project_project_estimates_path(@project), params: {
        estimate: {
          bill_to_name: "Custom Name",
          line_items_attributes: {
            "0" => { service_id: @service.id, description: "Hosting", quantity: "12", rate: "5000" },
            "1" => { service_id: "", description: "", quantity: "1", rate: "0", amount: "0" }
          }
        }
      }
    end

    estimate = Estimate.order(:id).last

    assert_redirected_to project_estimate_path(estimate)
    assert_equal "Custom Name", estimate.bill_to_name
    assert_equal 12 * 500_000, estimate.total_minor
    assert_equal 1, estimate.line_items.count
  end

  test "sends approves declines and reopens through transitions" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    post project_estimate_delivery_path(estimate)
    assert estimate.reload.sent?

    post project_estimate_approval_path(estimate)
    assert estimate.reload.approved?

    other = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)
    other.send_to_client!
    post project_estimate_decline_path(other)
    assert other.reload.declined?

    post project_estimate_reopening_path(other)
    assert other.reload.draft?
  end

  test "rejects transitions outside the lifecycle with an alert" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    post project_estimate_approval_path(estimate)

    assert_redirected_to project_estimate_path(estimate)
    assert_equal "Only sent estimates can be approved.", flash[:alert]
    assert estimate.reload.draft?
  end

  test "converts an approved estimate into an invoice snapshot" do
    estimate = @project.estimates.create!(
      workspace: @workspace, user: @user, customer: @customer,
      bill_to_name: "Custom Name",
      line_items_attributes: { "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" } }
    )
    estimate.send_to_client!
    estimate.approve!

    assert_difference("Invoice.count", 1) do
      post project_estimate_conversion_path(estimate)
    end

    invoice = Invoice.order(:id).last

    assert_redirected_to invoice_path(invoice)
    assert estimate.reload.invoiced?
    assert_equal @workspace, invoice.workspace
    assert_equal @customer, invoice.customer
    assert_equal @project, invoice.project
    assert_equal estimate, invoice.estimate
    assert_equal "NGN", invoice.currency_code
    assert_equal Date.current, invoice.issue_date
    assert_equal Date.current + 15.days, invoice.due_date
    assert_equal "Custom Name", invoice.bill_to_name
    assert_equal [ "Hosting" ], invoice.invoice_lines.map(&:description)
    assert_equal [ @service ], invoice.invoice_lines.map(&:service)
    assert_equal [ @income_account ], invoice.invoice_lines.map(&:account)
    assert_equal 12 * 500_000, invoice.total_minor
    assert_equal format("INV-%06d", invoice.id), invoice.invoice_number
  end

  test "carries an estimate through to a posted ledger entry end to end" do
    estimate = @project.estimates.create!(
      workspace: @workspace, user: @user, customer: @customer,
      line_items_attributes: { "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" } }
    )
    estimate.send_to_client!
    estimate.approve!

    post project_estimate_conversion_path(estimate)
    invoice = Invoice.order(:id).last

    assert estimate.reload.invoiced?
    assert_equal @project, invoice.project
    assert_equal estimate, invoice.estimate
    assert_equal 12 * 500_000, invoice.total_minor

    receivable = Account.for_role!(@workspace, :receivable)
    assert_difference("JournalEntry.count", 1) do
      post invoice_posting_path(invoice)
    end

    assert invoice.reload.posted?
    entry = invoice.journal_entry
    assert_equal 12 * 500_000, entry.journal_entry_lines.sum(&:debit_kobo)
    assert_equal 12 * 500_000, entry.journal_entry_lines.sum(&:credit_kobo)
    assert_equal [ receivable.id ], entry.journal_entry_lines.select { |line| line.debit_kobo.nonzero? }.map(&:account_id)
    assert_equal [ @income_account.id ], entry.journal_entry_lines.select { |line| line.credit_kobo.nonzero? }.map(&:account_id).uniq
  end

  test "rejects conversion of a non-approved estimate" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    assert_no_difference("Invoice.count") do
      post project_estimate_conversion_path(estimate)
    end

    assert_redirected_to project_estimate_path(estimate)
    assert_equal "Only approved estimates can be converted.", flash[:alert]
    assert estimate.reload.draft?
  end

  test "rejects converting an already invoiced estimate" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer,
      line_items_attributes: { "0" => { service: @service, description: "Hosting", quantity: 1, rate: 100 } })
    estimate.send_to_client!
    estimate.approve!
    post project_estimate_conversion_path(estimate)

    assert_no_difference("Invoice.count") do
      post project_estimate_conversion_path(estimate)
    end

    assert_redirected_to project_estimate_path(estimate)
    assert_equal "Only approved estimates can be converted.", flash[:alert]
  end

  test "locks invoiced estimates as read-only" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer,
      line_items_attributes: { "0" => { service: @service, description: "Hosting", quantity: 1, rate: 100 } })
    estimate.send_to_client!
    estimate.approve!
    post project_estimate_conversion_path(estimate)

    get edit_project_estimate_path(estimate)
    assert_redirected_to project_estimate_path(estimate)

    patch project_estimate_path(estimate), params: { project: { name: "Changed" }, estimate: { notes: "Changed" } }
    assert_redirected_to project_estimate_path(estimate)
    assert_nil estimate.reload.notes

    assert_no_difference("Estimate.count") do
      delete project_estimate_path(estimate)
    end
    assert_redirected_to project_estimate_path(estimate)
    assert estimate.reload.invoiced?
  end

  test "edits sent estimates" do
    estimate = @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)
    estimate.send_to_client!

    get edit_project_estimate_path(estimate)

    assert_response :success
    assert_select "p", text: "ESTIMATE"
  end

  test "scopes estimates to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "single", email: "o@example.com")
    other_project = other_workspace.projects.create!(customer: other_customer, name: "Other project")

    get project_project_estimates_path(other_project)

    assert_response :not_found
  end
end
