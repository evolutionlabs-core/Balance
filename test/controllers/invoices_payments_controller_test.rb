require "test_helper"

class Invoices::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income = @ledger.ledger_accounts.find_by!(name: "Other Income")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @service = @workspace.services.create!(name: "Consulting", income_ledger_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = sent_invoice
  end

  test "records the payment and settles the invoice" do
    assert_difference -> { LedgerEntry.count } => 1, -> { InvoicePayment.count } => 1 do
      post invoice_payment_path(@invoice), params: invoice_payment_params
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.paid?
    assert_equal 0, @invoice.balance_due_kobo

    entry = @invoice.payments.sole.ledger_entry
    lines = entry.ledger_lines.includes(:ledger_account).to_a

    assert_equal @cash.id, lines&.find { |line| line.debit.positive? }.ledger_account_id
    assert_equal 30_000, lines&.find { |line| line.debit.positive? }.debit
    assert_equal @ledger.ledger_accounts.find_by!(subtype: "accounts_receivable").id, lines&.find { |line| line.credit.positive? }.ledger_account_id
  end

  test "partial payments keep the invoice sent" do
    post invoice_payment_path(@invoice), params: invoice_payment_params(amount: "150.00")

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
    assert_equal 15_000, @invoice.balance_due_kobo
  end

  test "overpayments are refused with the form" do
    post invoice_payment_path(@invoice), params: invoice_payment_params(amount: "400.00")

    assert_response :unprocessable_content
    assert_select "li", text: /no more than the balance due/
    assert_equal 30_000, @invoice.reload.balance_due_kobo
    assert_equal 0, LedgerEntry.where(source_type: "InvoicePayment").count
  end

  test "rejects accounts outside the workspace payment accounts" do
    post invoice_payment_path(@invoice), params: {
      invoice_payment: {
        payment_ledger_account_id: @income.id,
        received_on: Date.current,
        amount: "150.00"
      }
    }

    assert_response :unprocessable_content
    assert_match /cash or credit-card/, response.body
  end

  test "draft invoices cannot receive payment" do
    draft = @workspace.invoices.create!(
      user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: 100 } ]
    )

    post invoice_payment_path(draft), params: invoice_payment_params

    assert_redirected_to invoice_path(draft)
    assert_match "Only a sent invoice", flash[:alert].to_s
  end

  private
    def sent_invoice
      invoice = @workspace.invoices.create!(
        user: users(:one), customer: @customer, issue_date: Date.current,
        invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
      )
      result = invoice.issue!
      raise "setup failure: #{invoice.errors.full_messages.join(', ')}" unless result

      invoice
    end

    def invoice_payment_params(amount: "300.00")
      { invoice_payment: {
        payment_ledger_account_id: @cash.id,
        received_on: Date.current,
        amount: amount
      } }
    end
end
