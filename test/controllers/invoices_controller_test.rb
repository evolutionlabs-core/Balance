require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Customer", customer_type: "business", email: "customer@example.com")
    @ledger = @workspace.provision_ledger!
    @income_account = @ledger.accounts.find_by!(name: "Other Income")
    @service = @workspace.services.create!(name: "Consulting", income_account: @income_account)
    sign_in_as(@user)
  end

  test "create saves a calculated workspace invoice and redirects to show" do
    assert_difference "@workspace.invoices.count", 1 do
      post invoices_path, params: invoice_params
    end

    invoice = @workspace.invoices.order(:id).last
    assert_redirected_to invoice_path(invoice)
    assert_equal [ @user, @customer, 30_000 ], [ invoice.user, invoice.customer, invoice.total_minor ]
    assert_equal 1, invoice.invoice_lines.count
  end

  test "invalid creation returns the populated form" do
    assert_no_difference "Invoice.count" do
      post invoices_path, params: { invoice: { currency_code: "NGN" } }
    end

    assert_response :unprocessable_content
    assert_select "li", text: /Customer can't be blank/
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
      customer_id: @customer.id,
      invoice_lines_attributes: { "-#{line.id}" => { service_id: @service.id, description: "Consulting", quantity: 3, rate: 150 } }
    } }

    assert_redirected_to invoice_path(invoice)
    assert_equal 45_000, invoice.reload.total_minor
  end

  test "locks sent invoices as read-only" do
    invoice = create_invoice
    assert invoice.issue!

    get edit_invoice_path(invoice)
    assert_redirected_to invoice_path(invoice)

    patch invoice_path(invoice), params: { invoice: { due_date: Date.current + 60.days } }
    assert_redirected_to invoice_path(invoice)
    assert_equal Date.current + 30.days, invoice.reload.due_date

    get invoice_path(invoice)
    assert_response :success
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Send invoice", count: 0
    assert_select "button[data-copy-value-value]", text: /Copy secure link/
    assert_select "form[action='#{invoice_settlement_path(invoice)}'] button", text: "Mark as paid"
  end

  test "a draft's header offers edit and send, with download and void in the menu" do
    invoice = create_invoice

    get invoice_path(invoice)

    assert_select "a[href='#{edit_invoice_path(invoice)}']", text: "Edit"
    assert_select "form[action='#{invoice_issuance_path(invoice)}'] button", text: "Send invoice"
    assert_select "[role=menu] a[href='#{invoice_path(invoice, format: :pdf)}']", text: /Download PDF/
    assert_select "[role=menu] a[href='#{new_invoice_void_path(invoice)}']", text: /Void invoice/
  end

  test "a sent invoice's header offers download and payment, with the client link and void in the menu" do
    invoice = create_invoice
    assert invoice.issue!

    get invoice_path(invoice)

    assert_select "a[href='#{invoice_path(invoice, format: :pdf)}']:not([role=menuitem])", text: /Download PDF/
    assert_select "form[action='#{invoice_settlement_path(invoice)}'] button", text: "Mark as paid"
    assert_select "[role=menu] a[href='#{new_invoice_payment_path(invoice)}']", text: /Record partial payment/
    assert_select "[role=menu] button[data-copy-value-value]", text: /Copy secure link/
    assert_select "[role=menu] a[href='#{new_invoice_void_path(invoice)}']", text: /Void invoice/
    assert_select "a", text: "Back to invoices", count: 0
  end

  test "draft invoices do not expose client links" do
    invoice = create_invoice

    get invoice_path(invoice)

    assert_response :success
    assert_select "button[data-copy-value-value]", text: /Copy secure link/, count: 0
  end

  test "show downloads the saved invoice as a PDF" do
    invoice = create_invoice
    get invoice_path(invoice, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment;.*invoice-#{invoice.id}\.pdf/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
  end

  test "show displays the remaining balance after a partial payment" do
    invoice = create_invoice
    assert invoice.issue!
    cash = @ledger.accounts.find_by!(name: "Cash")
    assert invoice.record_payment!(deposit_account_id: cash.id, received_on: Date.current, amount_kobo: 15_000)

    get invoice_path(invoice)

    assert_response :success
    assert_select "body", text: /Balance due.*NGN 150\.00/m
    get invoices_path
    assert_select "body", text: /Partially paid/
  end

  test "invoices are scoped to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "business", email: "other@example.com")
    service = other_workspace.services.create!(name: "Other Consulting", income_account: other_ledger.accounts.find_by!(name: "Sales"))
    invoice = other_workspace.invoices.create!(user: users(:two), customer: other_customer,
      invoice_lines_attributes: [ { service_id: service.id, description: "Consulting", quantity: 1, rate: 100 } ])

    get invoice_path(invoice)

    assert_response :not_found
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user,
        customer: @customer,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
      )
    end

    def invoice_params
      { invoice: {
        customer_id: @customer.id,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: {
          "0" => { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 },
          "1" => { service_id: "", description: "", quantity: 1, rate: 0, amount: 0 }
        }
      } }
    end
end
