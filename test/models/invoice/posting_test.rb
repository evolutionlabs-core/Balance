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

  test "a discount reduces income so the receivable matches the discounted total" do
    sales = @ledger.accounts.where(base_type: "income").where.not(id: @income.id).first!
    design = @workspace.services.create!(name: "Design", income_account: sales)
    invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current,
      discount_type: "percent", discount_value: "12.5",
      invoice_lines_attributes: [
        { service_id: @service.id, description: "Consulting", quantity: 1, rate: "333.33" },
        { service_id: design.id, description: "Design", quantity: 1, rate: "100.01" }
      ])
    assert_equal 37_917, invoice.total_minor

    assert invoice.issue!

    entry = JournalEntry.where(source_type: "Invoice", source_id: invoice.id, action: "issue").sole
    assert_equal 37_917, entry.journal_entry_lines.find { |line| line.account == @ar }.debit
    assert_equal 37_917, entry.journal_entry_lines.sum(&:credit)
    assert_equal 29_166, entry.journal_entry_lines.find { |line| line.account == @income }.credit
    assert_equal 8_751, entry.journal_entry_lines.find { |line| line.account == sales }.credit

    assert_not invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 43_334)
    assert invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 37_917)
    assert invoice.reload.paid?
  end

  test "voiding a discounted invoice reverses its entry" do
    @invoice.update!(discount_type: "amount", discount_value: 50)
    assert @invoice.issue!

    assert @invoice.void!

    assert_equal 0, @ledger.accounts.find_by!(id: @ar.id).journal_entry_lines.sum("debit - credit")
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

    assert_includes @invoice.errors.full_messages, "This invoice issue is already recorded as entry #1 with different lines"
  end

  test "records an application and settles the invoice at full application" do
   raise "setup failure" unless @invoice.issue!

    assert @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 30_000)

    assert @invoice.reload.paid?
    application = @invoice.payments.sole
    entry = application.journal_entry

    assert_equal 30_000, entry.journal_entry_lines.find { |line| line.debit.positive? }.debit
    assert_equal "Payment received for invoice #{@invoice.invoice_number}", entry.description
    assert_equal 0, @invoice.balance_due_kobo
  end

  test "partial applications keep the invoice sent" do
    raise "setup failure" unless @invoice.issue!

    assert @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 15_000)

    assert @invoice.reload.sent?
    assert_equal 15_000, @invoice.balance_due_kobo
  end

  test "amounts above the balance are refused" do
    raise "setup failure" unless @invoice.issue!

    assert_equal false, @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 40_000)

    assert_includes @invoice.errors.full_messages, "Payment amount must be no more than the balance due"
    assert_empty JournalEntry.where(source_type: "InvoicePayment")
    assert @invoice.reload.sent?
  end

  test "accounts outside the workspace payment accounts are refused" do
    raise "setup failure" unless @invoice.issue!

    assert_equal false, @invoice.record_payment!(deposit_account_id: @income.id, received_on: Date.current, amount_kobo: 15_000)

    assert_includes @invoice.errors.full_messages, "Deposit account must be a bank or cash account in this workspace"
  end

  test "draft invoices cannot receive payment" do
    draft = @workspace.invoices.create!(
      user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Work", quantity: 1, rate: 100 } ]
    )

    assert_equal false, draft.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)

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
    assert @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 10_000)

    assert_equal false, @invoice.void!

    assert_match /cannot be voided/, @invoice.errors.full_messages.join
    assert @invoice.reload.sent?
    assert_equal 20_000, @invoice.balance_due_kobo
  end

  test "paid invoices cannot be voided" do
    raise "setup failure" unless @invoice.issue!
    assert @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 30_000)

    assert_equal false, @invoice.void!

    assert @invoice.reload.paid?
  end


  test "mark as paid settles the full balance into the default deposit account today" do
    raise "setup failure" unless @invoice.issue!

    assert @invoice.mark_paid!

    assert @invoice.reload.paid?
    entry = @invoice.payments.sole.journal_entry
    assert_equal Date.current, entry.effective_date
    assert_equal @workspace.default_deposit_account, entry.journal_entry_lines.find { |line| line.debit.positive? }.account
  end

  test "mark as paid needs a default deposit account" do
    raise "setup failure" unless @invoice.issue!
    @invoice.workspace.update!(default_deposit_account: nil)

    assert_equal false, @invoice.mark_paid!
    assert_includes @invoice.errors.full_messages, "Choose a default deposit account in company settings before marking invoices as paid"
  end

  test "reversing a payment reopens the invoice and restores the receivable" do
    raise "setup failure" unless @invoice.issue!
    assert @invoice.mark_paid!
    payment = @invoice.payments.sole

    assert @invoice.reverse_payment!(payment)

    assert @invoice.reload.sent?
    assert_equal 30_000, @invoice.balance_due_kobo
    assert_equal payment.journal_entry, payment.reload.reversal_payment.journal_entry.reverses_entry
    assert_equal 30_000, @ar.journal_entry_lines.sum(:debit) - @ar.journal_entry_lines.sum(:credit)
  end

  test "a payment can only be reversed once" do
    raise "setup failure" unless @invoice.issue!
    assert @invoice.mark_paid!
    payment = @invoice.payments.sole
    assert @invoice.reverse_payment!(payment)

    assert_equal false, @invoice.reverse_payment!(payment.reload)
    assert_includes @invoice.errors.full_messages, "This payment has already been reversed"
  end

  test "credit-card accounts are not deposit accounts" do
    raise "setup failure" unless @invoice.issue!
    card = @ledger.accounts.find_by!(subtype: "credit_card")

    assert_equal false, @invoice.record_payment!(deposit_account_id: card.id, received_on: Date.current, amount_kobo: 10_000)
  end


  test "an invoice payment can't be dated in the future or before the invoice" do
    raise "setup failure" unless @invoice.issue!

    assert_equal false, @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current + 1, amount_kobo: 10_000)
    assert_includes @invoice.errors.full_messages, "Payment date can't be in the future"

    assert_equal false, @invoice.record_payment!(deposit_account_id: @cash.id, received_on: @invoice.issue_date - 1, amount_kobo: 10_000)
    assert_includes @invoice.errors.full_messages, "Payment date can't be before the invoice date"
  end

  test "voiding without a recorded issue entry is a form error, not an exception" do
    @invoice.update_columns(status: "sent", issue_date: Date.current)

    assert_equal false, @invoice.reload.void!
    assert_includes @invoice.errors.full_messages, "This invoice has no recorded entry to reverse"
  end

  private
    def owner
      User.create!(full_name: "Owner", email_address: "owner2@example.com", password: "supersecret123").tap do |user|
        @workspace.memberships.create!(user: user, role: :owner)
      end
    end
end
