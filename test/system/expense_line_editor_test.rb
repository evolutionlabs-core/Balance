require "application_system_test_case"

class ExpenseLineEditorTest < ApplicationSystemTestCase
  test "adds removes and totals category lines" do
    users(:one).update!(password: "password")

    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path

    visit new_expense_path

    assert_selector "[data-amount-lines-target='row']", count: 1
    amount_inputs.first.set("100.00")
    assert_selector "[data-amount-lines-target='total']", text: "100.00"

    click_on "Add category"
    assert_selector "[data-amount-lines-target='row']", count: 2
    amount_inputs.last.set("250.50")
    assert_selector "[data-amount-lines-target='total']", text: "350.50"

    within all("[data-amount-lines-target='row']").first do
      click_on "Remove category"
    end

    assert_selector "[data-amount-lines-target='row']", count: 1
    assert_selector "[data-amount-lines-target='total']", text: "250.50"
    assert_field type: "hidden", with: "0", name: /\[position\]/
  end

  private
    def amount_inputs
      all("[data-amount-lines-target='amount']")
    end
end
