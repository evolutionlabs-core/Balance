require "test_helper"

class Invoices::SettlementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    income = @ledger.accounts.find_by!(name: "Other Income")
    customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(user: users(:one), customer: customer, issue_date: Date.current,
      invoice_lines_attributes: [ { account_id: income.id, description: "Consulting", quantity: 2, rate: 150 } ])
  end

  test "marks a sent invoice as paid into the default deposit account" do
    assert @invoice.issue!

    post invoice_settlement_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert_equal "₦300.00 received into Checking Account.", flash[:notice]
    assert @invoice.reload.paid?
  end

  test "a draft invoice cannot be marked as paid" do
    assert_no_difference "JournalEntry.count" do
      post invoice_settlement_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert_match "Only a sent invoice with a balance", flash[:alert]
  end

  test "reverses a payment from the invoice page" do
    assert @invoice.issue!
    assert @invoice.mark_paid!
    payment = @invoice.payments.sole

    get invoice_path(@invoice)
    assert_select "#payments-heading", "Payments"
    assert_select "form[action='#{invoice_payment_reversal_path(@invoice, payment)}'] button", "Reverse"

    post invoice_payment_reversal_path(@invoice, payment)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
    follow_redirect!
    assert_select "td", "Reversed"
  end
end
