require "test_helper"

class Projects::BudgetsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    customer = @workspace.customers.create!(name: "Budget Customer", customer_type: "business", email: "budget@example.com")
    @project = @workspace.projects.create!(customer: customer, name: "Budget Project")
  end

  test "edit only shows the budget field" do
    get edit_project_project_budget_path(@project)

    assert_response :success
    assert_select "#modal dialog", text: /Set budget/
    assert_select "input[name='project[cost_budget]'][placeholder='Enter budget amount']"
    assert_select "input[name='project[name]']", count: 0
    assert_select "select[name='project[customer_id]']", count: 0
  end

  test "updates the project budget" do
    patch project_project_budget_path(@project), params: { project: { cost_budget: "100000" } }

    assert_redirected_to project_path(@project)
    assert_equal 10_000_000, @project.reload.cost_budget_kobo
  end

  test "rejects a negative budget" do
    patch project_project_budget_path(@project), params: { project: { cost_budget: "-5" } }

    assert_response :unprocessable_content
    assert_nil @project.reload.cost_budget_kobo
  end

  test "scopes projects to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    customer = other_workspace.customers.create!(name: "Other", customer_type: "business", email: "other-budget@example.com")
    other_project = other_workspace.projects.create!(customer: customer, name: "Other project")

    get edit_project_project_budget_path(other_project)

    assert_response :not_found
  end
end
