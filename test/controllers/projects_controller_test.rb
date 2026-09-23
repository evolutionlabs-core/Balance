require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Site Customer", customer_type: "business", email: "site@example.com")
    @bank = @workspace.accounts.create!(name: "Site Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @category = @workspace.accounts.create!(name: "Site Materials", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "creates a project and redirects to its overview" do
    assert_difference("Project.count", 1) do
      post projects_path, params: { project: { customer_id: @customer.id, name: "Villa" } }
    end

    assert_redirected_to project_path(Project.last)
  end

  test "edit excludes the project budget" do
    project = @workspace.projects.create!(customer: @customer, name: "Villa")

    get edit_project_path(project)

    assert_response :success
    assert_select "input[name='project[cost_budget]']", count: 0
  end

  test "updates project details without changing the budget" do
    project = @workspace.projects.create!(customer: @customer, name: "Villa")

    patch project_path(project), params: {
      project: { name: "Villa Updated", cost_budget: "100000" }
    }

    assert_redirected_to project_path(project)
    project.reload

    assert_equal "Villa Updated", project.name
    assert_nil project.cost_budget_kobo
  end

  test "ignores unknown nested attributes on update" do
    project = @workspace.projects.create!(customer: @customer, name: "Villa")

    patch project_path(project), params: {
      project: {
        name: "Villa Updated",
        unknown_items_attributes: { "0" => { description: "Foundation", quantity: "10" } }
      }
    }

    assert_redirected_to project_path(project)
    assert_equal "Villa Updated", project.reload.name
  end

  test "scopes projects to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "single", email: "o@example.com")
    other_project = other_workspace.projects.create!(customer: other_customer, name: "Other project")

    get project_path(other_project)

    assert_response :not_found
  end
end
