require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.contacts.create!(name: "Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])
    sign_in_as(@user)
  end

  test "create saves a calculated workspace invoice and redirects to show" do
    assert_difference "@workspace.invoices.count", 1 do
      post invoices_path, params: invoice_params
    end

    invoice = @workspace.invoices.order(:id).last
    assert_redirected_to invoice_path(invoice)
    assert_equal [ @user, @customer, 30_000 ], [ invoice.user, invoice.contact, invoice.total_minor ]
  end

  test "invalid creation returns the populated form" do
    assert_no_difference "Invoice.count" do
      post invoices_path, params: { invoice: { currency_code: "NGN" } }
    end

    assert_response :unprocessable_content
    assert_select "#invoice_errors", text: /Customer can't be blank/
  end

  test "index links rows to show and exposes a separate edit action" do
    invoice = create_invoice
    get invoices_path

    assert_select "tbody a[href=?]", invoice_path(invoice)
    assert_select "tbody a[href=?]", edit_invoice_path(invoice), text: "Edit"
  end

  test "update recalculates the invoice" do
    invoice = create_invoice
    line = invoice.invoice_lines.first

    patch invoice_path(invoice), params: { invoice: {
      contact_id: @customer.id,
      invoice_lines_attributes: { "-#{line.id}" => { description: "Consulting", quantity: 3, rate: 150 } }
    } }

    assert_redirected_to invoice_path(invoice)
    assert_equal 45_000, invoice.reload.total_minor
  end

  test "show downloads the saved invoice as a PDF" do
    invoice = create_invoice
    get invoice_path(invoice, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment;.*invoice-#{invoice.id}\.pdf/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
  end

  test "invoices are scoped to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_contact = other_workspace.contacts.create!(name: "Other", contact_kind: "business", email: "other@example.com", role_names: %w[customer])
    invoice = other_workspace.invoices.create!(user: users(:two), contact: other_contact)

    get invoice_path(invoice)

    assert_response :not_found
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user,
        contact: @customer,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate: 150 } ]
      )
    end

    def invoice_params
      { invoice: {
        contact_id: @customer.id,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: { "0" => { description: "Consulting", quantity: 2, rate: 150 } }
      } }
    end
end
