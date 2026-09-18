require "test_helper"

class Projects::TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Time Customer", customer_type: "business", email: "time@example.com")
    @project = @workspace.projects.create!(customer: @customer, name: "Time Project")
    @task = @project.tasks.create!(title: "Wiring")
  end

  test "index renders the work tab time view" do
    entry = @project.time_entries.create!(
      task: @task, occurred_on: Date.current, hours: 2, description: "Sockets"
    )

    get project_project_time_entries_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Work"
    assert_select "span[aria-current='page']", text: "Time entries"
    assert_select "td", text: entry.description
    assert_select "td", text: entry.hours.to_s
  end

  test "new preselects the task when logging time from a task" do
    get new_project_project_time_entry_path(@project, task_id: @task.id)

    assert_response :success
    assert_select "#modal select[name='project_time_entry[project_task_id]'] option[selected]", text: @task.title
  end

  test "creates a time entry and returns to the time view" do
    assert_difference("@project.time_entries.count", 1) do
      post project_project_time_entries_path(@project), params: {
        project_time_entry: {
          project_task_id: @task.id, occurred_on: Date.current.to_s,
          hours: "3", description: "Site work"
        }
      }
    end

    assert_redirected_to project_project_time_entries_path(@project)
    entry = @project.time_entries.order(:id).last

    assert_equal @task, entry.task
    assert_equal 3, entry.hours
  end

  test "updates a time entry" do
    entry = @project.time_entries.create!(
      task: @task, occurred_on: Date.current, hours: 2, description: "Sockets"
    )

    patch project_project_time_entry_path(@project, entry), params: {
      project_time_entry: { hours: "4" }
    }

    assert_redirected_to project_project_time_entries_path(@project)
    assert_equal 4, entry.reload.hours
  end

  test "destroys a time entry" do
    entry = @project.time_entries.create!(
      task: @task, occurred_on: Date.current, hours: 2, description: "Gone"
    )

    assert_difference("@project.time_entries.count", -1) do
      delete project_project_time_entry_path(@project, entry)
    end

    assert_redirected_to project_project_time_entries_path(@project)
  end
end
