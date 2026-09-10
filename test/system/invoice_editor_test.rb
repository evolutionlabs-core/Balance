require "application_system_test_case"

class InvoiceEditorTest < ApplicationSystemTestCase
  test "new stays unsaved until Save and preview and edit remains a separate path" do
    user = users(:one)
    user.update!(password: "password")
    workspace = workspaces(:ada_store)
    customer = workspace.contacts.create!(name: "Invoice Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path
    visit invoices_path
    click_on "New invoice", match: :first
    assert_current_path new_invoice_path
    within "nav[aria-label='Invoice views']" do
      assert_text "Preview"
      assert_no_text "Edit"
    end
    assert_selector "tr.invoice-line", count: 2
    assert_equal 0, workspace.invoices.count
    click_on "Save and preview"
    assert_text "Customer can't be blank"
    assert_current_path new_invoice_path
    assert_equal 0, workspace.invoices.count
    visit new_invoice_path

    fill_in "Customer", with: "Invoice"
    assert_selector "[role='option']", text: customer.name
    page.save_screenshot(Rails.root.join("tmp/screenshots/invoice_new_picker.png"))
    find("[role='option']", text: customer.name).click
    assert_field "invoice_bill_to_email", with: customer.email
    fill_in "invoice_bill_to_email", with: "custom@example.com"
    within all("tr.invoice-line").first do
      find("input[name$='[description]']").set("Consulting")
      find("input[name$='[quantity]']").set("2")
      find("input[name$='[rate]']").set("150")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 300.00"
    assert_equal 0, workspace.invoices.count
    assert_equal 0, InvoiceLine.count
    assert_field "invoice_bill_to_email", with: "custom@example.com"

    click_on "Add product or service"
    assert_selector "tr.invoice-line", count: 3
    within all("tr.invoice-line").last do
      find("input[name$='[description]']").set("Added item")
      find("input[name$='[quantity]']").set("1")
      find("input[name$='[rate]']").set("50")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 350.00"
    within all("tr.invoice-line")[1] do
      click_on "Remove line"
    end
    assert_selector "tr.invoice-line", count: 2
    assert_equal 0, workspace.invoices.count
    click_on "Save and preview"
    assert_text "Invoice draft saved."
    invoice = workspace.invoices.sole
    assert_current_path invoice_path(invoice)
    assert_equal 35_000, invoice.total_minor
    assert_equal customer, invoice.contact
    assert_equal "custom@example.com", invoice.bill_to_email
    assert_equal [ "Consulting", "Added item" ], invoice.invoice_lines.pluck(:description)

    visit invoices_path
    page.save_screenshot(Rails.root.join("tmp/screenshots/invoice_list.png"))
    within "tbody tr" do
      click_on customer.name, exact: true
    end
    assert_current_path invoice_path(invoice)
    visit invoices_path
    within "tbody tr" do
      click_on "Edit", exact: true
    end
    assert_current_path edit_invoice_path(invoice)
    assert_selector "nav[aria-label='Invoice views']"
    within all("tr.invoice-line").first do
      assert_no_button "Remove line"
    end
    within all("tr.invoice-line").last do
      click_on "Remove line"
    end
    assert_selector "#invoice_total", text: "NGN 300.00"
    assert_equal 2, invoice.invoice_lines.count
    visit edit_invoice_path(invoice)
    assert_selector "tr.invoice-line", count: 2
    within all("tr.invoice-line").last do
      click_on "Remove line"
    end
    assert_selector "tr.invoice-line", count: 1
    click_on "Add product or service"
    assert_selector "tr.invoice-line", count: 2
    assert_equal 2, invoice.invoice_lines.count
    within all("tr.invoice-line").last do
      click_on "Remove line"
    end
    assert_selector "tr.invoice-line", count: 1
    within all("tr.invoice-line").first do
      find("input[name$='[rate]']").set("75")
    end
    click_on "Save and preview"
    assert_current_path invoice_path(invoice)
    assert_equal 15_000, invoice.reload.total_minor
    assert_equal 1, workspace.invoices.count
  end
end
