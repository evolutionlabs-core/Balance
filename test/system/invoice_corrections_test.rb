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

  test "credits part of a sent invoice from its menu and voids the credit" do
    visit invoice_path(@invoice)
    find("button[aria-label='More invoice actions']").click
    click_on "Create credit note"

    assert_text "Saving lowers what Acme owes on #{@invoice.invoice_number}"
    find("input[aria-label='Quantity']").fill_in(with: "1")
    find("input[aria-label='Quantity']").send_keys(:tab)
    click_on "Save credit note"

    assert_selector "h1", text: /Credit note CN-/
    within("section", text: "Applied to") { assert_link @invoice.invoice_number }

    click_on @invoice.invoice_number
    assert_text "Credit applied"
    assert_text "Balance due\nNGN 150.00"

    assert_link CreditNote.last.number
    visit credit_note_path(CreditNote.last)
    click_on "Void"
    assert_selector "#modal", text: "Void credit note"
    within("#modal") { click_on "Void credit note" }

    assert_text "Voided"
    assert_equal 30_000, @invoice.reload.balance_due_kobo
  end

  test "changes the reference of a sent invoice" do
    visit invoice_path(@invoice)
    find("button[aria-label='More invoice actions']").click
    click_on "Edit details"

    within("#modal") do
      assert_text "Amounts are locked after sending"
      fill_in "PO / reference", with: "PO-7"
      click_on "Save"
    end

    assert_no_selector "#modal dialog"
    assert_text "PO-7"
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
