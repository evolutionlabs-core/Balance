require "test_helper"

class Invoices::IssuancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @service = @workspace.services.create!(name: "Consulting", income_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
  end

  test "sends the invoice and records the money owed in the ledger" do
    assert_difference -> { JournalEntry.count } => 1 do
      post invoice_issuance_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
    entry = JournalEntry.where(source_type: "Invoice", source_id: @invoice.id, action: "issue").sole
    lines = entry.journal_entry_lines.includes(:account).to_a.map { |line| [ line.account.name, line.debit, line.credit ] }

    assert_equal [ [ "Accounts Receivable", 30_000, 0 ], [ "Other Income", 0, 30_000 ] ], lines.sort
  end

  test "sending a sent invoice redirects with an alert" do
    @invoice.issue!

    assert_no_difference "JournalEntry.count" do
      post invoice_issuance_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert_match "Only draft invoices can be sent", flash[:alert].to_s
  end

  test "rejection keeps the invoice a draft" do
    @ledger.close_books!(through: Date.current, actor: owner)

    assert_no_difference "JournalEntry.count" do
      post invoice_issuance_path(@invoice)
    end

    assert_redirected_to invoice_path(@invoice)
    assert_match "closed through", flash[:alert].to_s
    assert @invoice.reload.draft?
  end

  test "cannot send an invoice from another workspace" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    service = other_workspace.services.create!(name: "S", income_account: other_ledger.accounts.find_by!(name: "Sales"))
    customer = other_workspace.customers.create!(name: "Other", customer_type: "business", email: "o@example.com")
    invoice = other_workspace.invoices.create!(user: users(:two), customer: customer,
      invoice_lines_attributes: [ { service_id: service.id, description: "Work", quantity: 1, rate: 100 } ])

    post invoice_issuance_path(invoice)

    assert_response :not_found
  end

  private
    def owner
      User.create!(full_name: "Owner", email_address: "owner@example.com", password: "supersecret123").tap do |user|
        @workspace.memberships.create!(user: user, role: :owner)
      end
    end
end
