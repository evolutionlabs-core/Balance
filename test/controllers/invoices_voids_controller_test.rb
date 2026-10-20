require "test_helper"

class Invoices::VoidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @service = @workspace.services.create!(name: "Consulting", income_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
  end

  test "voiding a draft records no journal entries" do
    assert_no_difference "JournalEntry.count" do
      post invoice_void_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.voided?
  end

  test "voiding a sent invoice posts the compensating entry" do
    @invoice.issue!

    assert_difference -> { JournalEntry.count } => 1 do
      post invoice_void_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.voided?
    ar = @ledger.accounts.find_by!(subtype: "accounts_receivable")

    assert_equal 0, ar.journal_entry_lines.sum(&:debit) - ar.journal_entry_lines.sum(&:credit)
  end

  test "voiding a sent invoice with an applied payment is refused" do
    @invoice.issue!
    check = @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)


    assert_no_difference "JournalEntry.count" do
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
