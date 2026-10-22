require "application_system_test_case"

class InvoiceEditorTest < ApplicationSystemTestCase
  test "shares a draft invoice's link through the device share sheet" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    income = workspace.provision_ledger!.accounts.find_by!(name: "Other Income")
    service = workspace.services.create!(name: "Consulting", income_account: income)
    customer = workspace.customers.create!(name: "Share Customer", customer_type: "business", email: "share@example.com")
    invoice = workspace.invoices.create!(user: user, customer: customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: service.id, description: "Consulting", quantity: 1, rate: 100 } ])
    sign_in(user)

    visit invoice_path(invoice)
    page.execute_script("navigator.share = (data) => { window.sharedUrl = data.url; return Promise.resolve() }")
    click_button "Send invoice"
    click_button "Share link…"

    assert_text "Invoice #{invoice.invoice_number} shared."
    assert invoice.reload.sent?
    assert_match %r{/client/invoices/.+}, page.evaluate_script("window.sharedUrl")
  end

  test "creates edits and sends a free-form invoice" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    income = ledger.accounts.find_by!(name: "Other Income")
    workspace.update!(default_sales_account: income)
    cash = ledger.accounts.find_by!(name: "Cash")
    customer = workspace.customers.create!(name: "Invoice Customer", customer_type: "business", email: "customer@example.com")
    sign_in(user)
    visit new_invoice_path
    assert_selector "tr.line-item", count: 1
    fill_in "Customer", with: "Invoice"
    find("[role='option']", text: customer.name).click
    assert_selector "input[name='invoice[customer_id]'][value='#{customer.id}']", visible: :all
    within all("tr.line-item").first do
      find("input[name$='[description]']").set("Consulting")
      find("input[name$='[quantity]']").set("2")
      find("input[name$='[rate]']").set("150")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 300.00"
    fill_in "invoice_bill_to_email", with: "custom@example.com"
    click_on "Add line"
    assert_selector "tr.line-item", count: 2
    within all("tr.line-item").last do
      click_on "Remove line"
    end
    assert_selector "tr.line-item", count: 1
    click_on "Save draft"

    assert_current_path %r{\A/invoices/\d+\z}
    invoice = workspace.invoices.reload.sole
    assert_equal [ 30_000, customer, "custom@example.com" ], [ invoice.total_minor, invoice.customer, invoice.bill_to_email ]
    visit edit_invoice_path(invoice)
    within "tr.line-item" do
      find("input[name$='[rate]']").set("75")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 150.00"
    click_on "Save draft"
    assert_current_path invoice_path(invoice)
    assert_equal 15_000, invoice.reload.total_minor

    click_on "PDF view"
    assert_selector "iframe[title='Invoice PDF'][src]"
    click_on "Email view"
    assert_field "Send to", with: "custom@example.com"
    click_button "Send invoice"
    click_button "Send email"
    assert_text "Invoice #{invoice.invoice_number} sent to custom@example.com"
    assert invoice.reload.sent?
    assert_equal income.id, invoice.invoice_lines.sole.account_id
    entry = JournalEntry.where(source_type: "Invoice", source_id: invoice.id, action: "issue").sole
    assert_equal 15_000, entry.journal_entry_lines.sum(&:debit)
    assert_no_link "Edit"

    click_on "Mark as paid"
    assert_text "₦150.00 received into Checking Account."
    assert_selector "dd", text: "NGN 0.00"
    assert_no_button "Mark as paid"
    assert_equal 0, invoice.reload.balance_due_kobo
    assert invoice.reload.paid?

    accept_confirm { click_on "Reverse" }
    assert_text "Payment reversed. Invoice #{invoice.invoice_number} is open again."
    assert_selector "td", text: "Reversed"
    assert invoice.reload.sent?
    assert_equal 15_000, invoice.balance_due_kobo
  end

  test "finds a service by typing, removes the first line, previews and goes to review" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    income = workspace.provision_ledger!.accounts.find_by!(name: "Other Income")
    workspace.services.create!(name: "Consulting", description: "Strategy consulting", default_rate: 250, income_account: income)
    customer = workspace.customers.create!(name: "Typing Customer", customer_type: "business", email: "typing@example.com")
    sign_in(user)

    visit new_invoice_path
    fill_in "Customer", with: "Typing"
    find("[role='option']", text: customer.name).click
    within "tr.line-item" do
      find("input[name$='[description]']").set("cons")
      find("[role='option']", text: "Consulting").click
      assert_field "Rate", with: "250.00"
      assert_text "Consulting"
    end
    assert_selector "#invoice_total", text: "NGN 250.00"

    click_on "Add line"
    assert_selector "tr.line-item", count: 2
    within all("tr.line-item").last do
      find("input[name$='[description]']").set("Travel")
      find("input[name$='[rate]']").set("50")
    end
    find("h2", text: "Product or service").click
    within(all("tr.line-item").first) { click_on "Remove line" }
    assert_selector "tr.line-item", count: 1
    assert_selector "#invoice_total", text: "NGN 50.00"

    click_on "Preview"
    within "#invoice_preview" do
      assert_text "Travel"
      assert_text "Typing Customer"
      assert_no_text "Strategy consulting"
    end

    click_on "Review and send"
    assert_field "Send to", with: "typing@example.com"
    invoice = workspace.invoices.reload.sole
    assert_current_path invoice_path(invoice, view: "email")
    assert_equal [ 5_000, [ "Travel" ] ], [ invoice.total_minor, invoice.invoice_lines.map(&:description) ]
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
