require "application_system_test_case"

class InvoiceEditorTest < ApplicationSystemTestCase
  test "edits the draft through customer and line resources" do
    user = users(:one)
    user.update!(password: "password")
    customer = workspaces(:ada_store).contacts.create!(
      name: "Invoice Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer]
    )
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path
    visit new_invoice_path
    click_on "Create draft"
    assert_text "Changes are saved to this draft."
    invoice = workspaces(:ada_store).invoices.sole

    find("summary", text: "Select a customer").click
    fill_in "Search customers", with: "Invoice"
    click_on "Search", exact: true
    click_on customer.name, exact: true
    assert_field "invoice_bill_to_email", with: customer.email
    assert_equal customer.id, invoice.reload.contact_id
    fill_in "invoice_bill_to_email", with: "custom@example.com"
    find("h2", text: "Product or service").click
    assert_no_selector "form[aria-busy='true']"

    click_on "Add product or service"
    assert_selector "tr.invoice-line", count: 1
    within all("tr.invoice-line").first do
      find("input[name$='[description]']").set("Consulting")
      find("input[name$='[quantity]']").set("2")
      find("input[name$='[rate]']").set("150")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 300.00"
    assert_field "invoice_bill_to_email", with: "custom@example.com"
    assert_equal "custom@example.com", invoice.reload.bill_to_email
    assert_equal 30_000, invoice.total_minor

    click_on "Add product or service"
    assert_selector "tr.invoice-line", count: 2
    within all("tr.invoice-line").last do
      find("input[name$='[description]']").set("Added item")
      find("input[name$='[quantity]']").set("1")
      find("input[name$='[rate]']").set("50")
    end
    find("h2", text: "Product or service").click
    assert_selector "#invoice_total", text: "NGN 350.00"
    within all("tr.invoice-line").first do
      click_on "Remove line"
    end
    assert_selector "tr.invoice-line", count: 1
    assert_selector "#invoice_total", text: "NGN 50.00"
    assert_equal [ "Added item" ], invoice.reload.invoice_lines.pluck(:description)
    assert_equal 5_000, invoice.total_minor
    assert_no_selector "input[name='invoice[contact_id]'], input[name^='invoice[business_'], input[type='hidden'][name^='invoice[bill_to_']", visible: :all

    visit edit_invoice_path(invoice)
    assert_selector "tr.invoice-line", count: 1
    assert_field "invoice_bill_to_email", with: "custom@example.com"
    click_on "Edit company"
    fill_in "Business name", with: "Updated Company"
    fill_in "Business address", with: "14 Marina Road"
    click_on "Save changes"
    assert_selector "turbo-frame##{dom_id(invoice, :business)}", text: "Updated Company"
    assert_equal "Updated Company", invoice.reload.business_name

    click_on "Edit customer"
    fill_in "contact_email", with: "updated@example.com"
    click_on "Save changes"
    assert_no_selector "#modal form"
    assert_field "invoice_bill_to_email", with: "updated@example.com"
    assert_equal "updated@example.com", invoice.reload.bill_to_email

    click_on "Preview", match: :first
    assert_current_path invoice_path(invoice)
    assert_text "Added item"
    assert_text "Updated Company"
  end
end
