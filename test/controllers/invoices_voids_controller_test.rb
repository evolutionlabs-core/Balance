require "test_helper"

class Invoices::VoidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income = @ledger.ledger_accounts.find_by!(name: "Other Income")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @service = @workspace.services.create!(name: "Consulting", income_ledger_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
  end

  test "voiding a draft records no ledger entries" do
    assert_no_difference "LedgerEntry.count" do
      post invoice_void_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.voided?
  end

  test "voiding a sent invoice posts the compensating entry" do
    @invoice.issue!

    assert_difference -> { LedgerEntry.count } => 1 do
      post invoice_void_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.voided?
    ar = @ledger.ledger_accounts.find_by!(subtype: "accounts_receivable")

    assert_equal 0, ar.ledger_lines.sum(&:debit) - ar.ledger_lines.sum(&:credit)
  end

  test "voiding a sent invoice with an applied payment is refused" do
    @invoice.issue!
    check = @invoice.record_payment!(payment_ledger_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)


    assert_no_difference "LedgerEntry.count" do
      post invoice_void_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
  end

  private
    def owner
      User.create!(full_name: "Owner", email_address: "voidowner@example.com", password: "supersecret123").tap do |user|
        @workspace.memberships.create!(user: user, role: :owner)
      end
    end
end
