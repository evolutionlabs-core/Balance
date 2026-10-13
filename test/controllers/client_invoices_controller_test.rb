require "test_helper"

class ClientInvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Portal Customer", customer_type: "business",
      email: "portal@example.com")
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    income = @ledger.ledger_accounts.find_by!(name: "Other Income")
    service = @workspace.services.create!(name: "Portal service", income_ledger_account: income)
    @invoice = @workspace.invoices.create!(user: @user, customer: @customer, issue_date: Date.current,
      due_date: Date.current + 30.days, currency_code: "NGN",
      invoice_lines_attributes: [ { service_id: service.id, description: "Consulting", quantity: 2, rate: 150 } ])
    raise "setup failure" unless @invoice.issue!

    @token = @invoice.generate_token_for(:client_view)
  end

  test "client views a sent invoice without touching the books" do
    ledger_entry_count = LedgerEntry.count
    application_count = InvoicePayment.count

    get client_invoice_path(@token)

    assert_response :success
    assert_select "h1", text: @invoice.invoice_number
    assert_select "body", text: /Portal Customer/
    assert_select "a[href=?]", client_invoice_path(@token, format: :pdf), text: "Download PDF"
    assert_select "#sidebar-panel", count: 0
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_equal ledger_entry_count, LedgerEntry.count
    assert_equal application_count, InvoicePayment.count
    assert @invoice.reload.sent?
  end

  test "client downloads the sent invoice PDF" do
    get client_invoice_path(@token, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment;.*invoice-#{@invoice.invoice_number}\.pdf/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
  end

  test "draft and voided invoices are not available through client links" do
    draft = @workspace.invoices.create!(user: @user, customer: @customer, currency_code: "NGN")

    get client_invoice_path(draft.generate_token_for(:client_view))
    assert_response :not_found

    draft.void!
    get client_invoice_path(draft.generate_token_for(:client_view))
    assert_response :not_found
  end

  test "invalid and expired client links are not found" do
    get client_invoice_path("#{@token}tampered")
    assert_response :not_found

    travel 91.days do
      get client_invoice_path(@token)
      assert_response :not_found
    end
  end
end
