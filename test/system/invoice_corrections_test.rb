require "application_system_test_case"

class InvoiceCorrectionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(password: "password")
    @workspace = workspaces(:ada_store)
    @workspace.provision_ledger!
    customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: @user, customer: customer, issue_date: Date.current,
      invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
    sign_in(@user)
  end

  test "credits part of a sent invoice and voids the credit" do
    visit invoice_path(@invoice)
    find("button[aria-label='More invoice actions']").click
    click_on "Credit note"

    within("#modal") do
      fill_in "Amount", with: "100.00"
      fill_in "Reason", with: "Returned one item"
      click_on "Issue credit note"
    end

    assert_no_selector "#modal dialog"
    within("section", text: "Credit notes") { assert_text "Returned one item" }
    assert_text "Balance due\nNGN 200.00"

    accept_confirm { click_on "Void" }

    assert_text "Voided"
    assert_text "Balance due\nNGN 300.00"
  end

  test "changes the due date of a sent invoice and shows the change" do
    visit invoice_path(@invoice)
    find("button[aria-label='More invoice actions']").click
    click_on "Edit details"

    within("#modal") do
      assert_text "Amounts are locked after sending"
      fill_in "PO / reference", with: "PO-7"
      click_on "Save"
    end

    within("section", text: "Changes") { assert_text "Reference: — → PO-7" }
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
