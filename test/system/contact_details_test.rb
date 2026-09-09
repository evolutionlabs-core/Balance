require "application_system_test_case"

class ContactDetailsTest < ApplicationSystemTestCase
  setup do
    @workspace = workspaces(:ada_store)
    @vendor = @workspace.contacts.create!(name: "Fuel Station", contact_kind: "business", email: "fuel@example.com", role_names: %w[vendor])
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
    expense = create_expense_for(@vendor)

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

    def create_expense_for(contact)
      bank = @workspace.accounts.create!(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
      fuel = @workspace.accounts.create!(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")

      @workspace.expenses.create!(
        payment_date: Date.current,
        payment_account: bank,
        payee_contact: contact,
        memo: "Generator fuel",
        expense_lines_attributes: [ { account: fuel, description: "Fuel", amount_kobo: 4_000_000, position: 0 } ]
      )
    end
end
