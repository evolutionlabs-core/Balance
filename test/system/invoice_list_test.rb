require "application_system_test_case"

class InvoiceListTest < ApplicationSystemTestCase
  test "searches invoices as you type" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    income = workspace.provision_ledger!.accounts.find_by!(name: "Other Income")
    service = workspace.services.create!(name: "Consulting", income_account: income)
    [ "Adaeze Stores", "Bayo Logistics" ].each do |name|
      customer = workspace.customers.create!(name: name, customer_type: "business", email: "#{name.parameterize}@example.com")
      workspace.invoices.create!(user: user, customer: customer, issue_date: Date.current,
        invoice_lines_attributes: [ { service_id: service.id, description: "Consulting", quantity: 1, rate: 100 } ])
    end
    sign_in(user)

    visit invoices_path
    fill_in "q", with: "bayo"

    assert_selector "#invoices tbody tr", count: 1
    assert_selector "#invoices tbody td", text: "Bayo Logistics"
    assert_field "q", with: "bayo", focused: true
    assert_link "Clear"
  end

  private
    def sign_in(user)
      visit new_session_path
      fill_in "Email", with: user.email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end
end
