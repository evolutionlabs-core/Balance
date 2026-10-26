require "test_helper"

class CreditNote::PostingTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @sales = @ledger.accounts.where(base_type: "income").where.not(id: @income.id).first!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @ar = @ledger.accounts.find_by!(subtype: "accounts_receivable")
    @workspace.update!(default_sales_account: @income)
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @consulting = @workspace.services.create!(name: "Consulting", income_account: @income)
    @design = @workspace.services.create!(name: "Design", income_account: @sales)
  end

  test "a credit from an invoice debits each income account, credits the customer's receivable and lowers that invoice" do
    invoice = sent_invoice(lines: [ [ @consulting, 3, 100 ], [ @design, 1, 100 ] ])
    credit_note = CreditNote.from_invoice(invoice, user: users(:one))
    credit_note.lines.first.mark_for_destruction

    assert credit_note.issue!

    assert_match(/\ACN-\d{6}\z/, credit_note.number)
    entry = credit_note.journal_entry
    assert_equal @ledger, entry.ledger
    assert_equal [ "CreditNote", credit_note.id, "issue" ], [ entry.source_type, entry.source_id, entry.action ]
    assert_equal({ @sales => [ 10_000, 0 ], @ar => [ 0, 10_000 ] }, entry_lines(entry))
    assert_equal @customer, entry.journal_entry_lines.find { |line| line.account == @ar }.customer

    assert_equal [ [ invoice, 10_000 ] ], credit_note.applications.map { |application| [ application.invoice, application.amount_minor ] }
    assert_equal 30_000, invoice.reload.balance_due_kobo
    assert invoice.sent?
    assert_equal 0, credit_note.unapplied_minor
  end

  test "a credit from a discounted invoice totals the invoice and posts income net of the discount" do
    invoice = sent_invoice(lines: [ [ @consulting, 3, 100 ], [ @design, 1, 100 ] ], discount: 100)
    credit_note = CreditNote.from_invoice(invoice, user: users(:one))

    assert credit_note.issue!

    assert_equal 30_000, credit_note.total_minor
    assert_equal({ @income => [ 22_500, 0 ], @sales => [ 7_500, 0 ], @ar => [ 0, 30_000 ] }, entry_lines(credit_note.journal_entry))
    assert invoice.reload.paid?
    assert_equal 0, receivable_balance
  end

  test "credit beyond the invoice balance stays with the customer and settles their next invoice" do
    invoice = sent_invoice(lines: [ [ @consulting, 1, 100 ] ])
    credit_note = new_credit_note(invoice: invoice, amount: 150)

    assert credit_note.issue!

    assert invoice.reload.paid?
    assert_equal 5_000, credit_note.reload.unapplied_minor

    next_invoice = sent_invoice(lines: [ [ @consulting, 1, 80 ] ])

    assert_equal 3_000, next_invoice.reload.balance_due_kobo
    assert_equal 0, credit_note.reload.unapplied_minor
    assert_equal 3_000, receivable_balance
  end

  test "a credit without an invoice goes to the customer's oldest unpaid invoices first" do
    older = sent_invoice(lines: [ [ @consulting, 1, 100 ] ], issue_date: Date.current - 20)
    newer = sent_invoice(lines: [ [ @consulting, 1, 100 ] ], issue_date: Date.current - 5)

    assert new_credit_note(amount: 150).issue!

    assert older.reload.paid?
    assert_equal 5_000, newer.reload.balance_due_kobo
    assert newer.sent?
  end

  test "rejected credits leave the books untouched" do
    invoice = sent_invoice(lines: [ [ @consulting, 1, 100 ] ])

    without_dates = new_credit_note(invoice: invoice, amount: 100, issued_on: nil)
    without_lines = @workspace.credit_notes.build(customer: @customer, invoice: invoice, user: users(:one), issued_on: Date.current,
      lines_attributes: [ { description: "", quantity: "", rate: "", amount: "" } ])
    without_customer = new_credit_note(amount: 100).tap { |credit_note| credit_note.customer = nil }

    assert_no_difference [ "CreditNote.count", "JournalEntry.count", "CreditApplication.count" ] do
      assert_not without_dates.issue!
      assert_not without_lines.issue!
      assert_not without_customer.issue!
    end
    assert_includes without_dates.errors.full_messages, "Issued on can't be blank"
    assert_includes without_lines.errors.full_messages, "Add at least one line"
    assert_includes without_customer.errors.full_messages, "Customer must exist"
    assert_equal 10_000, invoice.reload.balance_due_kobo
  end

  test "a line without an income account is refused" do
    @workspace.update!(default_sales_account: nil)
    credit_note = @workspace.credit_notes.build(customer: @customer, user: users(:one), issued_on: Date.current,
      lines_attributes: [ { description: "Refund", quantity: 1, rate: 10 } ])

    assert_no_difference -> { JournalEntry.count } do
      assert_not credit_note.issue!
    end
    assert_includes credit_note.errors.full_messages, "Choose a default income account in Settings, or pick a service for each line"
    assert credit_note.new_record?
  end

  test "voiding a credit note mirrors its entry and gives the invoices their balance back" do
    invoice = sent_invoice(lines: [ [ @consulting, 1, 100 ] ])
    credit_note = new_credit_note(invoice: invoice, amount: 100)
    assert credit_note.issue!
    assert invoice.reload.paid?

    assert credit_note.void!

    reversal = credit_note.reload.void_journal_entry
    assert_equal credit_note.journal_entry, reversal.reverses_entry
    assert_equal [ "CreditNote", credit_note.id, "void" ], [ reversal.source_type, reversal.source_id, reversal.action ]
    assert_empty credit_note.applications
    assert invoice.reload.sent?
    assert_equal 10_000, invoice.balance_due_kobo
    assert_equal 10_000, receivable_balance

    assert_not credit_note.void!
    assert_includes credit_note.errors.full_messages, "This credit note has already been voided"
  end

  test "voiding an invoice frees its credit for the next invoice" do
    invoice = sent_invoice(lines: [ [ @consulting, 1, 100 ] ])
    credit_note = new_credit_note(invoice: invoice, amount: 40)
    assert credit_note.issue!

    assert invoice.void!

    assert_equal 4_000, credit_note.reload.unapplied_minor
    assert_equal(-4_000, receivable_balance)
  end

  test "a payment cannot exceed the balance left after a credit" do
    invoice = sent_invoice(lines: [ [ @consulting, 1, 100 ] ])
    assert new_credit_note(invoice: invoice, amount: 40).issue!

    payment = invoice.payments.build(workspace: @workspace, amount_kobo: 6_001)

    assert_not payment.valid?
    assert invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 6_000)
    assert invoice.reload.paid?
  end

  test "credit notes are immutable once issued" do
    credit_note = new_credit_note(amount: 40)
    assert credit_note.issue!

    assert_not credit_note.update(notes: "Changed")
    assert_not credit_note.destroy
  end

  test "the receivables aging ties out with applied and unapplied credit" do
    sent_invoice(lines: [ [ @consulting, 1, 100 ] ])
    assert new_credit_note(amount: 150).issue!

    aging = AgedBalances.new(@workspace, side: :receivables)

    assert aging.tied_out?
    assert_equal(-5_000, aging.total_kobo)
  end

  private
    def sent_invoice(lines:, discount: nil, issue_date: Date.current)
      invoice = @workspace.invoices.create!(
        user: users(:one), customer: @customer, issue_date: issue_date,
        discount_type: ("amount" if discount), discount_value: discount,
        invoice_lines_attributes: lines.map { |service, quantity, rate| { service_id: service.id, description: service.name, quantity: quantity, rate: rate } }
      )
      assert invoice.issue!
      invoice
    end

    def new_credit_note(amount:, invoice: nil, issued_on: Date.current)
      @workspace.credit_notes.build(customer: @customer, invoice: invoice, user: users(:one), issued_on: issued_on,
        lines_attributes: [ { service_id: @consulting.id, description: "Returned item", quantity: 1, rate: amount } ])
    end

    def entry_lines(entry)
      entry.journal_entry_lines.to_h { |line| [ line.account, [ line.debit, line.credit ] ] }
    end

    def receivable_balance
      @ar.journal_entry_lines.sum("debit - credit")
    end
end
