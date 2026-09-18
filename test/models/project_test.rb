require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @other_workspace = workspaces(:bola_shop)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Project Customer", customer_type: "business", email: "project@example.com")
    @bank = @workspace.accounts.create!(name: "Project Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @category = @workspace.accounts.create!(name: "Project Materials", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "requires workspace customer and name" do
    project = @workspace.projects.build(customer: @customer, name: "Office fit-out")

    assert project.valid?, project.errors.full_messages.to_sentence
  end

  test "rejects customer from another workspace" do
    other_customer = @other_workspace.customers.create!(name: "Other", customer_type: "single", email: "other@example.com")
    project = @workspace.projects.build(customer: other_customer, name: "Bad project")

    assert_not project.valid?
    assert_includes project.errors[:customer], "must belong to the workspace"
  end

  test "time entries link to tasks" do
    project = @workspace.projects.create!(customer: @customer, name: "Fixed project")
    task = project.tasks.create!(title: "Fixed install")
    entry = project.time_entries.create!(
      task: task, occurred_on: Date.current, hours: 4, description: "Installed units"
    )

    assert_equal task, entry.task
    assert_equal 4, entry.hours
  end

  test "budget comparison appears only when a budget is set" do
    project = @workspace.projects.create!(customer: @customer, name: "Budget project")

    assert_not project.summary.has_budget?

    project.update!(cost_budget: "1000")

    assert project.summary.has_budget?
    assert_equal 100_000, project.summary.budget_kobo
  end
end
