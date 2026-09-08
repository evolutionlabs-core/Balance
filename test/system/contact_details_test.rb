require "application_system_test_case"

class ContactDetailsTest < ApplicationSystemTestCase
  setup do
    @workspace = workspaces(:ada_store)
    @vendor = create_vendor(@workspace, name: "Fuel Station")
    users(:one).update!(password: "password")
    sign_in
  end

  test "opens the contact details page from anywhere on the row" do
    visit contacts_path

    find("tr##{dom_id(@vendor)}").click

    assert_current_path contact_path(@vendor)
    assert_selector "h1", text: "Fuel Station"
    assert_selector "h2", text: "Transaction history"
  end

  test "keeps the edit action independent of row navigation" do
    visit contacts_path

    find("a[aria-label='Edit Fuel Station']").click

    assert_selector "#modal", text: "Edit contact"
    assert_current_path contacts_path
  end

  test "lists the expenses paid to the contact" do
    bank = create_payment_account(@workspace)
    fuel = create_expense_account(@workspace)
    expense = create_expense(@workspace, payee_contact: @vendor, payment_account: bank, category: fuel, memo: "Generator fuel")

    visit contact_path(@vendor)

    assert_selector "tr##{dom_id(expense)}", text: "Generator fuel"
    assert_selector "tr##{dom_id(expense)}", text: "Checking"
  end

  test "shows an empty state for a contact with no activity" do
    visit contact_path(@vendor)

    assert_selector "h2", text: "No transactions yet"
    assert_no_selector "table"
  end

  private
    def sign_in
      visit new_session_path
      fill_in "Email", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end
end
