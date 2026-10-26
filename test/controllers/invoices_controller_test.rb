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

  test "review and send saves the draft and opens the email view" do
    post invoices_path(next: "send"), params: invoice_params

    assert_redirected_to invoice_path(@workspace.invoices.order(:id).last, view: "email")
  end

  test "editing a draft shows its number and lets every line be removed" do
    invoice = create_invoice

    get edit_invoice_path(invoice)

    assert_select "#invoice_number", text: invoice.invoice_number
    assert_select "tr.line-item button[value=delete]", count: 1
    assert_select "input[name$='[rate]'][value='150.00']"
  end

  test "new invoices start with the workspace terms, payment details and note" do
    @workspace.update!(default_payment_terms: "net_15", payment_instructions: "GTBank 0123456789", default_invoice_note: "Thanks")

    get new_invoice_path

    assert_select "select[name='invoice[payment_terms]'] option[selected][value=net_15]"
    assert_select "input[name='invoice[due_date]'][value=?]", (Date.current + 15.days).iso8601
    assert_select "textarea[name='invoice[payment_instructions]']", text: "GTBank 0123456789"
    assert_select "textarea[name='invoice[notes]']", text: "Thanks"
    assert_select "tr.line-item", count: 1
  end

  test "create saves terms, reference, notes and discount" do
    post invoices_path, params: invoice_params.deep_merge(invoice: {
      payment_terms: "net_7", due_date: "", reference: "PO-1", notes: "Thanks", internal_note: "Repeat client",
      payment_instructions: "GTBank", discount_type: "percent", discount_value: "10"
    })

    invoice = @workspace.invoices.order(:id).last
    assert_equal [ "net_7", invoice.issue_date + 7.days ], [ invoice.payment_terms, invoice.due_date ]
    assert_equal [ "PO-1", "Thanks", "Repeat client", "GTBank" ], [ invoice.reference, invoice.notes, invoice.internal_note, invoice.payment_instructions ]
    assert_equal [ 3_000, 27_000 ], [ invoice.discount_minor, invoice.total_minor ]
  end

  test "drafts without terms show Custom and keep their due date when edited" do
    invoice = create_invoice
    invoice.update_column(:payment_terms, nil)

    get edit_invoice_path(invoice)
    assert_select "select[name='invoice[payment_terms]'] option[selected][value=custom]"

    patch invoice_path(invoice), params: { invoice: { reference: "PO-2", payment_terms: "custom" } }, as: :turbo_stream
    assert_equal [ "PO-2", Date.current + 30.days ], [ invoice.reload.reference, invoice.due_date ]
  end

  test "invalid creation returns the populated form" do
    assert_no_difference "Invoice.count" do
      post invoices_path, params: { invoice: { customer_id: "" } }
    end

    assert_response :unprocessable_content
    assert_select "li", text: /Customer can't be blank/
  end

  test "index links rows to show and offers the next step for each invoice" do
    draft = create_invoice
    sent = create_invoice
    assert sent.issue!

    get invoices_path

    assert_select "thead th", text: "Action"
    assert_select "tbody a[href=?]", invoice_path(draft)
    assert_select "tbody a[href=?]", invoice_path(draft, view: "email"), text: "Send"
    assert_select "tbody a[href=?][data-turbo-frame=modal]", new_invoice_payment_path(sent), text: "Receive payment"
  end

  test "index flags overdue invoices and totals what is owed" do
    invoice = create_invoice
    invoice.update!(issue_date: Date.current - 40.days, due_date: Date.current - 10.days)
    assert invoice.issue!
    create_invoice

    get invoices_path

    assert_select "tbody td", text: "Overdue 10 days"
    assert_select "a[href=?]", invoices_path(status: "overdue"), text: /Overdue · 1/
  end

  test "index filters by status and searches by number or customer" do
    draft = create_invoice
    sent = create_invoice
    assert sent.issue!

    get invoices_path(status: "draft")
    assert_select "tbody a[href=?]", invoice_path(draft)
    assert_select "tbody a[href=?]", invoice_path(sent), count: 0

    get invoices_path(q: sent.invoice_number)
    assert_select "tbody a[href=?]", invoice_path(sent)
    assert_select "tbody a[href=?]", invoice_path(draft), count: 0

    get invoices_path(q: "nobody")
    assert_select "body", text: /No invoices found/
  end

  test "index shows 20 invoices per page and keeps the filters when paging" do
    invoices = Array.new(21) { create_invoice }

    get invoices_path(status: "draft")
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{invoices_path}?status=draft&page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get invoices_path(status: "draft", page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", invoice_path(invoices.first)
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index hides pagination when everything fits on one page" do
    create_invoice

    get invoices_path

    assert_select "nav[aria-label=Pagination]", count: 0
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
    assert_select "a, button", text: "Send invoice", count: 0
    assert_select "button[data-copy-value-value]", text: /Copy secure link/
    assert_select "[role=menu] button[data-controller=share]:not([data-share-issue-url-value])", text: /Share link/
    assert_select "a[href='#{new_invoice_payment_path(invoice)}']", text: "Receive payment"
  end

  test "a draft's header offers edit and send, with download and void in the menu" do
    invoice = create_invoice

    get invoice_path(invoice)

    assert_select "a[href='#{edit_invoice_path(invoice)}']", text: "Edit"
    assert_select "button[aria-haspopup=menu]", text: /Send invoice/
    assert_select "[role=menu] button[form=invoice-delivery][name='delivery[send_email]'][value='1']", text: /Send email/
    assert_select "[role=menu] button[data-controller=share][data-share-issue-url-value='#{invoice_issuance_path(invoice)}']", text: /Share link/
    assert_select "[role=menu] button[form=invoice-delivery][value='0']", text: /Mark as sent/
    assert_select "[role=tab]", text: /Customer view/
    assert_select "[role=tab]", text: /Email view/
    assert_select "[role=tab]", text: /PDF view/
    assert_select "[role=menu] a[href='#{invoice_path(invoice, format: :pdf)}']", text: /Download PDF/
    assert_select "[role=menu] a[href='#{new_invoice_void_path(invoice)}']", text: /Void invoice/
  end

  test "a sent invoice's header offers receive payment and download, with the client link and void in the menu" do
    invoice = create_invoice
    assert invoice.issue!

    get invoice_path(invoice)

    assert_select "a[href='#{invoice_path(invoice, format: :pdf)}']:not([role=menuitem])", text: /Download PDF/
    assert_select "a[href='#{new_invoice_payment_path(invoice)}']:not([role=menuitem])", text: /Receive payment/
    assert_select "a, button", text: /Mark as paid|partial payment/, count: 0
    assert_select "[role=menu] button[data-copy-value-value]", text: /Copy secure link/
    assert_select "[role=menu] button[data-controller=share]:not([data-share-issue-url-value])", text: /Share link/
    assert_select "[role=menu] a[href='#{new_invoice_void_path(invoice)}']", text: /Void invoice/
    assert_select "[role=menu] form[action='#{invoice_duplicate_path(invoice)}'] button", text: /Duplicate/
    assert_select "a", text: "Back to invoices", count: 0
  end

  test "a paid invoice leads with download and offers duplicate" do
    invoice = create_invoice
    assert invoice.issue!
    assert invoice.mark_paid!

    get invoice_path(invoice)

    assert_select "a.bg-balance-teal-700[href='#{invoice_path(invoice, format: :pdf)}']", text: /Download PDF/
    assert_select "form[action='#{invoice_duplicate_path(invoice)}'] button[role=menuitem]", count: 0
    assert_select "form[action='#{invoice_duplicate_path(invoice)}'] button", text: /Duplicate/
    assert_select "a", text: /Receive payment/, count: 0
  end

  test "each list row has a menu with the actions for its status" do
    draft = create_invoice
    sent = create_invoice
    assert sent.issue!

    get invoices_path

    assert_select "#invoice_#{draft.id} [role=menu]" do
      assert_select "a[href='#{edit_invoice_path(draft)}']", text: /Edit/
      assert_select "a[href='#{invoice_path(draft, format: :pdf)}']", text: /Download PDF/
      assert_select "form[action='#{invoice_duplicate_path(draft)}'] button", text: /Duplicate/
      assert_select "button[data-copy-value-value]", count: 0
    end
    assert_select "#invoice_#{sent.id} [role=menu]" do
      assert_select "a", text: /Edit/, count: 0
      assert_select "button[data-copy-value-value]", text: /Copy secure link/
      assert_select "a[href='#{new_invoice_void_path(sent)}']", text: /Void invoice/
    end
  end

  test "draft invoices do not expose client links" do
    invoice = create_invoice

    get invoice_path(invoice)

    assert_response :success
    assert_select "button[data-copy-value-value]", count: 0
    assert_select "[role=menu] button[data-controller=share]:not([data-share-issue-url-value])", count: 0
  end

  test "the internal note stays off everything the customer sees" do
    invoice = create_invoice
    invoice.update!(internal_note: "Secret margin", notes: "Thanks", payment_instructions: "GTBank 0123456789", reference: "PO-9")
    assert invoice.issue!

    get invoice_path(invoice)
    assert_select "p", text: /Internal note · Secret margin/
    assert_select "article", text: /Secret margin/, count: 0
    assert_select "article", text: /GTBank 0123456789/
    assert_select "article", text: /PO-9/

    get client_invoice_path(invoice.generate_token_for(:client_view))
    assert_response :success
    assert_no_match "Secret margin", response.body
    assert_match "GTBank 0123456789", response.body

    mail = InvoiceMailer.with(invoice: invoice, to: "a@example.com", subject: "Invoice", message: "Hello").issued
    assert_no_match "Secret margin", mail.body.encoded
    assert_match "GTBank 0123456789", mail.html_part.body.decoded
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
