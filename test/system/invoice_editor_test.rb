require "application_system_test_case"

class InvoiceEditorTest < ApplicationSystemTestCase
  test "creates and edits an invoice" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    customer = workspace.contacts.create!(name: "Invoice Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])
    sign_in(user)
    visit new_invoice_path
    assert_selector "tr.invoice-line", count: 2
    fill_in "Customer", with: "Invoice"
    find("[role='option']", text: customer.name).click
    within all("tr.invoice-line").first do
      find("input[name$='[description]']").set("Consulting")
      find("input[name$='[quantity]']").set("2")
      find("input[name$='[rate]']").set("150")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 300.00"
    fill_in "invoice_bill_to_email", with: "custom@example.com"
    within all("tr.invoice-line").last do
      click_on "Remove line"
    end
    click_on "Save and preview"

    assert_current_path %r{\A/invoices/\d+\z}
    invoice = workspace.invoices.reload.sole
    assert_equal [ 30_000, customer, "custom@example.com" ], [ invoice.total_minor, invoice.contact, invoice.bill_to_email ]
    visit edit_invoice_path(invoice)
    within "tr.invoice-line" do
      find("input[name$='[rate]']").set("75")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 150.00"
    click_on "Save and preview"
    assert_current_path invoice_path(invoice)
    assert_equal 15_000, invoice.reload.total_minor
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
