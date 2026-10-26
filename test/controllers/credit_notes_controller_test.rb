require "test_helper"

class CreditNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    ledger = @workspace.provision_ledger!
    @income = ledger.accounts.find_by!(name: "Other Income")
    @workspace.update!(default_sales_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @service = @workspace.services.create!(name: "Consulting", income_account: @income)
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
  end

  test "starting from an invoice copies its customer and lines and explains what saving does" do
    get new_credit_note_path(invoice_id: @invoice.id)

    assert_response :success
    assert_select "input[type=hidden][name='credit_note[invoice_id]'][value=?]", @invoice.id.to_s
    assert_select "input[name*='[description]'][value='Consulting']"
    assert_select "p", text: /Saving lowers what Acme owes on\s+#{@invoice.invoice_number}/
  end

  test "starting from scratch asks for the customer" do
    get new_credit_note_path

    assert_response :success
    assert_select "select[name='credit_note[customer_id]'] option", text: "Acme"
    assert_select "p", text: /oldest unpaid invoices/
  end

  test "draft invoices cannot be credited" do
    draft = @workspace.invoices.create!(user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { description: "Consulting", quantity: 1, rate: 100 } ])

    get new_credit_note_path(invoice_id: draft.id)

    assert_response :not_found
  end

  test "saving a credit from an invoice lowers its balance and shows the credit on it" do
    assert_difference -> { CreditNote.count } => 1, -> { JournalEntry.count } => 1 do
      post credit_notes_path, params: credit_note_params(rate: "100.00")
    end

    credit_note = CreditNote.last
    assert_redirected_to credit_note_path(credit_note)
    assert_equal 20_000, @invoice.reload.balance_due_kobo

    get invoice_path(@invoice)
    assert_select "dt", text: "Credit applied"
    assert_select "#credits-heading + * a[href=?]", credit_note_path(credit_note), text: credit_note.number
  end

  test "the credit note page shows where the credit went" do
    post credit_notes_path, params: credit_note_params(rate: "400.00")
    credit_note = CreditNote.last

    get credit_note_path(credit_note)

    assert_response :success
    assert_select "h1", text: "Credit note #{credit_note.number}"
    assert_select "a[href=?]", invoice_path(@invoice), text: @invoice.invoice_number
    assert_select "p", text: /100\.00\s+left as credit for Acme's next invoice/
  end

  test "an incomplete credit note is shown again with its errors" do
    assert_no_difference -> { CreditNote.count } do
      post credit_notes_path, params: credit_note_params.deep_merge(credit_note: { issued_on: "" })
    end

    assert_response :unprocessable_content
    assert_select "li", text: "Issued on can't be blank"
    assert_equal 30_000, @invoice.reload.balance_due_kobo
  end

  test "lists credit notes" do
    post credit_notes_path, params: credit_note_params

    get credit_notes_path

    assert_response :success
    assert_select "td a", text: CreditNote.last.number
    assert_select "td span", text: "Applied"
  end

  test "downloads a PDF" do
    post credit_notes_path, params: credit_note_params

    get credit_note_path(CreditNote.last, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "voiding gives the invoice its balance back" do
    post credit_notes_path, params: credit_note_params
    credit_note = CreditNote.last

    get new_credit_note_void_path(credit_note)
    assert_response :success

    assert_difference -> { JournalEntry.count } => 1 do
      post credit_note_void_path(credit_note)
    end

    assert_redirected_to credit_note_path(credit_note)
    assert credit_note.reload.voided?
    assert_equal 30_000, @invoice.reload.balance_due_kobo
  end

  test "recalculates totals as lines change" do
    post credit_note_calculation_path, params: { credit_note: { lines_attributes: { "0" => { description: "Item", quantity: "2", rate: "25", amount: "50" } } } },
      as: :turbo_stream

    assert_response :success
    assert_match "NGN 50.00", response.body
  end

  test "cannot open another workspace's credit note" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "business", email: "other@example.com")
    other = other_workspace.credit_notes.create!(customer: other_customer, user: users(:one), issued_on: Date.current,
      lines_attributes: [ { description: "X", quantity: 1, rate: 1 } ])

    get credit_note_path(other)

    assert_response :not_found
  end

  private
    def credit_note_params(rate: "300.00")
      { credit_note: {
        customer_id: @customer.id, invoice_id: @invoice.id, issued_on: Date.current.iso8601, notes: "Returned one item",
        lines_attributes: { "0" => { service_id: @service.id, description: "Consulting", quantity: "1", rate: rate, amount: rate } }
      } }
    end
end
