require "test_helper"

class Invoices::CreditNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
  end

  test "the form starts at the full balance" do
    get new_invoice_credit_note_path(@invoice)

    assert_response :success
    assert_select "input[name='credit_note[amount]'][value='300.00'][max='300.00']"
    assert_select "textarea[name='credit_note[reason]'][required]"
  end

  test "issues a credit note and shows it on the invoice" do
    assert_difference -> { CreditNote.count } => 1, -> { JournalEntry.count } => 1 do
      post invoice_credit_note_path(@invoice), params: credit_note_params(amount: "100.00")
    end

    assert_redirected_to invoice_path(@invoice)
    assert_equal 20_000, @invoice.reload.balance_due_kobo

    get invoice_path(@invoice)
    credit_note = @invoice.credit_notes.sole
    assert_select "#credit-notes-heading", text: "Credit notes"
    assert_select "td", text: credit_note.number
    assert_select "dt", text: /Credit note #{credit_note.number}\s+Returned one item/
    assert_select "dd", text: "NGN 200.00"
  end

  test "crediting the full balance marks the invoice credited" do
    post invoice_credit_note_path(@invoice), params: credit_note_params

    get invoice_path(@invoice)
    assert_select "h1 + *", text: /Credited/
  end

  test "an amount above the balance is refused with the form" do
    assert_no_difference -> { CreditNote.count } do
      post invoice_credit_note_path(@invoice), params: credit_note_params(amount: "300.01")
    end

    assert_response :unprocessable_content
    assert_select "li", text: "Credit amount must be no more than the balance due"
    assert_select "textarea[name='credit_note[reason]']", text: "Returned one item"
  end

  test "a settled invoice cannot be credited" do
    post invoice_credit_note_path(@invoice), params: credit_note_params

    get new_invoice_credit_note_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
  end

  test "voiding a credit note restores the balance" do
    post invoice_credit_note_path(@invoice), params: credit_note_params
    credit_note = @invoice.credit_notes.sole

    assert_difference -> { JournalEntry.count } => 1 do
      post invoice_credit_note_void_path(@invoice, credit_note)
    end

    assert_redirected_to invoice_path(@invoice)
    assert credit_note.reload.voided?
    assert @invoice.reload.sent?
    assert_equal 30_000, @invoice.balance_due_kobo
  end

  test "cannot credit another workspace invoice" do
    other_workspace = workspaces(:bola_shop)
    customer = other_workspace.customers.create!(name: "Other", customer_type: "business", email: "other@example.com")
    other = other_workspace.invoices.create!(user: users(:one), customer: customer, invoice_lines_attributes: [ { description: "X", quantity: 1, rate: 1 } ])

    get new_invoice_credit_note_path(other)

    assert_response :not_found
  end

  private
    def credit_note_params(amount: "300.00")
      { credit_note: { amount: amount, issued_on: Date.current.iso8601, reason: "Returned one item" } }
    end
end
