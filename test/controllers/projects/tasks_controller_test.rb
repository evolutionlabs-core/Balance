require "test_helper"

class Projects::TasksControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Work Customer", customer_type: "business", email: "work@example.com")
    @project = @workspace.projects.create!(customer: @customer, name: "Work Project")
  end

  test "index renders the work tab with tasks view and log-time actions" do
    task = @project.tasks.create!(title: "Build")

    get project_project_tasks_path(@project)

    assert_response :success
    assert_select "span[aria-current='page']", text: "Work"
    assert_select "span[aria-current='page']", text: "Tasks"
    assert_select "td", text: task.title
    assert_select "a[data-turbo-frame='modal']", text: "Add task"
    assert_select "a[href=?][data-turbo-frame='modal']",
      new_project_project_time_entry_path(@project, task_id: task.id), text: "Log time"
  end

  test "creates a task and returns to the work tab" do
    assert_difference("@project.tasks.count", 1) do
      post project_project_tasks_path(@project), params: {
        project_task: { title: "Build", status: "todo" }
      }
    end

    assert_redirected_to project_project_tasks_path(@project)
    assert_equal "Build", @project.tasks.order(:id).last.title
  end

  test "updates a task" do
    task = @project.tasks.create!(title: "Build")

    patch project_project_task_path(@project, task), params: {
      project_task: { title: "Renovate", status: "doing" }
    }

    assert_redirected_to project_project_tasks_path(@project)
    task.reload

    assert_equal "Renovate", task.title
    assert_equal "doing", task.status
  end

  test "destroys a task" do
    task = @project.tasks.create!(title: "Gone")

    assert_difference("@project.tasks.count", -1) do
      delete project_project_task_path(@project, task)
    end

    assert_redirected_to project_project_tasks_path(@project)
  end
end
