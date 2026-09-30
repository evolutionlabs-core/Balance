require "application_system_test_case"

class InvoiceEditorTest < ApplicationSystemTestCase
  test "creates edits and posts a free-form invoice" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    income = workspace.accounts.create!(name: "Consulting income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    workspace.update!(default_sales_account: income)
    Account.for_role!(workspace, :receivable)
    bank = Account.for_role!(workspace, :checking)
    customer = workspace.customers.create!(name: "Invoice Customer", customer_type: "business", email: "customer@example.com")
    sign_in(user)
    visit new_invoice_path
    assert_selector "tr.invoice-line", count: 2
    fill_in "Customer", with: "Invoice"
    find("[role='option']", text: customer.name).click
    assert_selector "input[name='invoice[customer_id]'][value='#{customer.id}']", visible: :all
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
    assert_selector "tr.invoice-line", count: 1
    click_on "Save and preview"

    assert_current_path %r{\A/invoices/\d+\z}
    invoice = workspace.invoices.reload.sole
    assert_equal [ 30_000, customer, "custom@example.com" ], [ invoice.total_minor, invoice.customer, invoice.bill_to_email ]
    visit edit_invoice_path(invoice)
    within "tr.invoice-line" do
      find("input[name$='[rate]']").set("75")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 150.00"
    click_on "Save and preview"
    assert_current_path invoice_path(invoice)
    assert_equal 15_000, invoice.reload.total_minor

    click_on "Issue invoice"
    within "#modal dialog" do
      assert_text "Consulting"
      assert_no_selector "select"
      click_on "Issue invoice"
    end
    assert_text "Invoice #{invoice.invoice_number} issued."
    assert invoice.reload.posted?
    assert_equal income, invoice.invoice_lines.sole.account
    assert_equal 15_000, invoice.journal_entry.journal_entry_lines.sum(:credit_kobo)
    assert_no_link "Edit"

    click_on "Invoice paid"
    within "#modal dialog" do
      select bank.name, from: "Bank or Cash account"
      click_on "Record payment"
    end
    assert_text "Payment recorded for invoice #{invoice.invoice_number}."
    assert_selector "dd", text: "NGN 0.00"
    assert_no_link "Invoice paid"
    assert_equal 0, invoice.reload.balance_due_kobo
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
