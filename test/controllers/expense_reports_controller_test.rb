require "test_helper"

class ExpenseReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
  end

  test "shows the expense reports and filters" do
    get expense_report_path

    assert_response :success
    assert_select "h1", "Expense reports"
    assert_select "form[action='#{expense_report_path}'][data-controller='date-range']"
    assert_select "input[data-date-range-target='input']"
    assert_select "input[name='from'][data-date-range-target='from']"
    assert_select "input[name='to'][data-date-range-target='to']"
    assert_select "select[name='vendor_id']", count: 0
    assert_select "select[name='category_id']"
  end
end
