require "test_helper"

class Invoice::PostingTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @ar = @ledger.accounts.find_by!(subtype: "accounts_receivable")
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @service = @workspace.services.create!(name: "Consulting", income_account: @income)
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
  end

  test "sends the invoice and posts issue to the engine" do
    assert @invoice.issue!

    assert @invoice.reload.sent?
    entry = JournalEntry.where(source_type: "Invoice", source_id: @invoice.id, action: "issue").sole

    assert_equal @ledger, entry.ledger
    assert_equal @ar, entry.journal_entry_lines.find { |line| line.debit.positive? }.account
    assert_equal 30_000, entry.journal_entry_lines.sum(&:debit)
    assert_equal 30_000, entry.journal_entry_lines.sum(&:credit)
  end

  test "rejection rolls the invoice back to draft" do
    Rule.create!(name: "block invoices", severity: "block", message: "invoicing paused by policy")

    assert_equal false, @invoice.issue!

    assert_includes @invoice.errors.full_messages, "invoicing paused by policy"
    assert @invoice.reload.draft?
    assert_empty JournalEntry.where(source_type: "Invoice")
  end

  test "a closed ledger period rejects sending" do
    @ledger.close_books!(through: Date.current, actor: owner)

    assert_equal false, @invoice.issue!

    assert_match /closed through/, @invoice.errors.full_messages.join
    assert @invoice.reload.draft?
  end

  test "a line whose account is not an income account is rejected before sending" do
    expense = @ledger.accounts.find_by!(name: "Groceries")
    invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: 100 } ]
    )
    invoice.invoice_lines.first.update_columns(account_id: expense.id)
    invoice.reload

    assert_equal false, invoice.issue!

    assert_match /is not an income account/, invoice.errors.full_messages.join
    assert invoice.reload.draft?
    assert_empty JournalEntry.where(source_type: "Invoice")
  end

  test "a second issue against an already recorded invoice rejects instead of crashing" do
    stale_entry = JournalEntry.create!(
      ledger: @ledger, number: 1, effective_date: Date.current, source_type: "Invoice",
      source_id: @invoice.id, action: "issue"
    )
    JournalEntryLine.create!(journal_entry: stale_entry, account: @ar, debit: 100)

    assert_equal false, @invoice.issue!

    assert_includes @invoice.errors.full_messages, "Invoice has already been sent."
  end

  test "records an application and settles the invoice at full application" do
   raise "setup failure" unless @invoice.issue!

    assert @invoice.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 30_000)

    assert @invoice.reload.paid?
    application = @invoice.payments.sole
    entry = application.journal_entry

    assert_equal 30_000, entry.journal_entry_lines.find { |line| line.debit.positive? }.debit
    assert_equal "Payment received for invoice #{@invoice.invoice_number}", entry.description
    assert_equal 0, @invoice.balance_due_kobo
  end

  test "partial applications keep the invoice sent" do
    raise "setup failure" unless @invoice.issue!

    assert @invoice.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 15_000)

    assert @invoice.reload.sent?
    assert_equal 15_000, @invoice.balance_due_kobo
  end

  test "amounts above the balance are refused" do
    raise "setup failure" unless @invoice.issue!

    assert_equal false, @invoice.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 40_000)

    assert_includes @invoice.errors.full_messages, "Payment amount must be no more than the balance due"
    assert_empty JournalEntry.where(source_type: "InvoicePayment")
    assert @invoice.reload.sent?
  end

  test "accounts outside the workspace payment accounts are refused" do
    raise "setup failure" unless @invoice.issue!

    assert_equal false, @invoice.record_payment!(payment_account_id: @income.id, received_on: Date.current, amount_kobo: 15_000)

    assert_includes @invoice.errors.full_messages, "Payment account must be a cash or credit-card account in this workspace"
  end

  test "draft invoices cannot receive payment" do
    draft = @workspace.invoices.create!(
      user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Work", quantity: 1, rate: 100 } ]
    )

    assert_equal false, draft.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)

    assert_includes draft.errors.full_messages, "Only a sent invoice with a balance can receive payment"
  end

  test "voiding a draft leaves the ledger untouched" do
    assert @invoice.void!

    assert @invoice.reload.voided?
    assert_empty @ledger.journal_entries
  end

  test "voiding a sent invoice posts the mirror entry and clears the receivable" do
    raise "setup failure" unless @invoice.issue!

    assert @invoice.void!

    assert @invoice.reload.voided?
    void_entry = JournalEntry.where(source_type: "Invoice", source_id: @invoice.id, action: "void").sole
    issue_entry = JournalEntry.where(source_type: "Invoice", source_id: @invoice.id, action: "issue").sole

    assert_equal issue_entry, void_entry.reverses_entry
    assert_equal [ @invoice.customer ], issue_entry.journal_entry_lines.where(account: @ar).map(&:customer)
    assert_equal [ @invoice.customer ], void_entry.journal_entry_lines.where(account: @ar).map(&:customer)
    assert_equal 30_000, void_entry.journal_entry_lines.sum(&:credit)
    assert_equal 0, @ar.journal_entry_lines.sum(&:debit) - @ar.journal_entry_lines.sum(&:credit)
  end

  test "a sent invoice with an applied payment cannot be voided" do
    raise "setup failure" unless @invoice.issue!
    assert @invoice.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)

    assert_equal false, @invoice.void!

    assert_match /cannot be voided/, @invoice.errors.full_messages.join
    assert @invoice.reload.sent?
    assert_equal 20_000, @invoice.balance_due_kobo
  end

  test "paid invoices cannot be voided" do
    raise "setup failure" unless @invoice.issue!
    assert @invoice.record_payment!(payment_account_id: @cash.id, received_on: Date.current, amount_kobo: 30_000)

    assert_equal false, @invoice.void!

    assert @invoice.reload.paid?
  end

  private
    def owner
      User.create!(full_name: "Owner", email_address: "owner2@example.com", password: "supersecret123").tap do |user|
        @workspace.memberships.create!(user: user, role: :owner)
      end
    end
end
