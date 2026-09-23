require "application_system_test_case"

class CustomerDetailsTest < ApplicationSystemTestCase
  setup do
    @workspace = workspaces(:ada_store)
    @customer = @workspace.customers.create!(name: "Ada Obi", customer_type: "single", email: "ada@example.com")
    users(:one).update!(password: "password")
    sign_in
  end

  test "opens the customer details page from anywhere on the row" do
    visit customers_path

    find("tr##{dom_id(@customer)}").click

    assert_current_path customer_path(@customer)
    assert_selector "h1", text: "Ada Obi"
  end

  test "keeps the edit action independent of row navigation" do
    visit customers_path

    find("a[aria-label='Edit Ada Obi']").click

    assert_selector "#modal", text: "Edit customer"
    assert_current_path customers_path
  end

  test "shows customer details without transaction history" do
    visit customer_path(@customer)

    assert_selector "h1", text: "Ada Obi"
    assert_no_selector "h2", text: "Transaction history"
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
