require "test_helper"

class Projects::EstimatesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Estimate Customer", customer_type: "business", email: "estimate@example.com")
    @project = @workspace.projects.create!(customer: @customer, name: "Estimate Villa")
  end

  test "show downloads the estimate as a PDF" do
    estimate = @project.estimates.create!(
      workspace: @workspace, user: @user, customer: @customer,
      line_items_attributes: { "0" => { description: "Hosting", quantity: "12", rate: "5000" } }
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

  test "lists estimates with status on the tab" do
    @project.estimates.create!(workspace: @workspace, user: @user, customer: @customer)

    get project_project_estimates_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Estimates"
    assert_select "td", text: /EST-/
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

    get edit_project_estimate_path(estimate)
    assert_response :success
    assert_select "p", text: "ESTIMATE"
  end

  test "line item controls return turbo streams without persisting an estimate" do
    headers = { Accept: "text/vnd.turbo-stream.html" }
    attributes = { estimate: { currency_code: "NGN", line_items_attributes: {
      "0" => { description: "First", quantity: 2, rate: 150 },
      "123456789" => { description: "Added", quantity: 1, rate: 50 }
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
            "0" => { description: "Hosting", quantity: "12", rate: "5000" }
          }
        }
      }
    end

    estimate = Estimate.order(:id).last

    assert_redirected_to project_estimate_path(estimate)
    assert_equal "Custom Name", estimate.bill_to_name
    assert_equal 12 * 500_000, estimate.total_minor
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
