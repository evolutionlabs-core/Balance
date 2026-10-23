require "application_system_test_case"

class AccountFormTest < ApplicationSystemTestCase
  setup do
    workspaces(:ada_store).provision_ledger!
    users(:one).update!(password: "password")
    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path
  end

  test "subtypes follow the selected type" do
    visit accounts_path
    click_on "New account"

    within "#modal" do
      find("button[role=combobox]", text: "Select type").click
    end
    find("[role=option]", text: "Expense").click

    within("#modal") { find("input[role=combobox][placeholder='Select subtype']").click }
    expense = all("[role=option]").map(&:text)
    assert_includes expense, "Groceries"
    assert_not_includes expense, "Cash"
    find("[role=option]", text: "Groceries").click

    within("#modal") { find("button[role=combobox]", text: "Expense").click }
    find("[role=option]", text: "Asset").click

    within("#modal") { find("input[role=combobox]").click }
    asset = all("[role=option]").map(&:text)
    assert_includes asset, "Cash"
    assert_not_includes asset, "Groceries"
    assert_equal "", find("select#account_subtype", visible: :all).value
  end
end
