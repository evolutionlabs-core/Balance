require "test_helper"

class Invoice::CreditNoteTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @sales = @ledger.accounts.where(base_type: "income").where.not(id: @income.id).first!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @ar = @ledger.accounts.find_by!(subtype: "accounts_receivable")
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    consulting = @workspace.services.create!(name: "Consulting", income_account: @income)
    design = @workspace.services.create!(name: "Design", income_account: @sales)
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current - 5,
      discount_type: "amount", discount_value: 100,
      invoice_lines_attributes: [
        { service_id: consulting.id, description: "Consulting", quantity: 3, rate: 100 },
        { service_id: design.id, description: "Design", quantity: 1, rate: 100 }
      ]
    )
    assert @invoice.issue!
    assert_equal 30_000, @invoice.total_minor
  end

  test "a partial credit debits income in proportion to the posted invoice and credits the customer's receivable" do
    assert credit(10_001)

    credit_note = @invoice.credit_notes.sole
    assert_match(/\ACN-\d{6}\z/, credit_note.number)
    assert_equal users(:one), credit_note.user
    entry = credit_note.journal_entry
    assert_equal @ledger, entry.ledger
    assert_equal [ "CreditNote", credit_note.id, "issue" ], [ entry.source_type, entry.source_id, entry.action ]
    assert_equal Date.current, entry.effective_date

    lines = entry.journal_entry_lines
    assert_equal 7_501, lines.find { |line| line.account == @income }.debit
    assert_equal 2_500, lines.find { |line| line.account == @sales }.debit
    receivable = lines.find { |line| line.account == @ar }
    assert_equal [ 0, 10_001 ], [ receivable.debit, receivable.credit ]
    assert_equal @customer, receivable.customer

    assert_equal 19_999, @invoice.reload.balance_due_kobo
    assert @invoice.sent?
  end

  test "crediting the whole balance settles the invoice" do
    assert credit(30_000)

    assert @invoice.reload.paid?
    assert_equal 0, @invoice.balance_due_kobo
    assert_equal 0, receivable_balance
  end

  test "a credit after a part payment can only cover what is still owed" do
    assert @invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 20_000)

    assert_not credit(10_001)
    assert_includes @invoice.errors.full_messages, "Credit amount must be no more than the balance due"

    assert credit(10_000)
    assert @invoice.reload.paid?
  end

  test "rejected credits leave the books and the invoice untouched" do
    assert_no_difference -> { CreditNote.count } do
      assert_no_difference -> { JournalEntry.count } do
        assert_not credit(0)
        assert_not credit(30_001)
        assert_not credit(1_000, on: Date.current + 1)
        assert_not credit(1_000, on: @invoice.issue_date - 1)
        assert_not credit(1_000, reason: "")
      end
    end

    messages = @invoice.errors.full_messages
    assert_includes messages, "Reason can't be blank"
    assert @invoice.reload.sent?
    assert_equal 30_000, @invoice.balance_due_kobo
  end

  test "draft invoices cannot be credited" do
    draft = @workspace.invoices.create!(user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { description: "Consulting", quantity: 1, rate: 100 } ])

    assert_not draft.issue_credit_note!(amount_minor: 1_000, issued_on: Date.current, reason: "Returned", user: users(:one))

    assert_includes draft.errors.full_messages, "Only a sent invoice with a balance can be credited"
  end

  test "a payment cannot exceed the balance left after a credit" do
    assert credit(25_000)

    payment = @invoice.payments.build(workspace: @workspace, amount_kobo: 5_001)

    assert_not payment.valid?
    assert_includes payment.errors[:amount_kobo], "cannot exceed the invoice balance"
  end

  test "voiding a credit note mirrors its entry and reopens the invoice" do
    assert credit(30_000)
    credit_note = @invoice.credit_notes.sole

    assert @invoice.void_credit_note!(credit_note)

    credit_note.reload
    assert credit_note.voided?
    reversal = credit_note.void_journal_entry
    assert_equal credit_note.journal_entry, reversal.reverses_entry
    assert_equal [ "CreditNote", credit_note.id, "void" ], [ reversal.source_type, reversal.source_id, reversal.action ]
    assert_equal 30_000, reversal.journal_entry_lines.find { |line| line.account == @ar }.debit
    assert @invoice.reload.sent?
    assert_equal 30_000, @invoice.balance_due_kobo
    assert_equal 30_000, receivable_balance
  end

  test "a credit note can only be voided once" do
    assert credit(1_000)
    credit_note = @invoice.credit_notes.sole
    assert @invoice.void_credit_note!(credit_note)

    assert_no_difference -> { JournalEntry.count } do
      assert_not @invoice.void_credit_note!(credit_note.reload)
    end
    assert_includes @invoice.errors.full_messages, "This credit note has already been voided"
  end

  test "an invoice with an active credit note cannot be voided" do
    assert credit(1_000)

    assert_not @invoice.void!
    assert @invoice.reload.sent?

    assert @invoice.void_credit_note!(@invoice.credit_notes.sole)
    assert @invoice.void!
    assert_equal 0, receivable_balance
  end

  test "credit notes are immutable once issued" do
    assert credit(1_000)
    credit_note = @invoice.credit_notes.sole

    assert_not credit_note.update(amount_minor: 2_000)
    assert_not credit_note.destroy
    assert_equal 1_000, credit_note.reload.amount_minor
  end

  test "the receivables aging still ties out to the ledger after credits" do
    assert credit(4_000)
    assert credit(6_000)
    assert @invoice.void_credit_note!(@invoice.credit_notes.first)

    aging = AgedBalances.new(@workspace, side: :receivables)

    assert aging.tied_out?
    assert_equal 24_000, aging.total_kobo
  end

  private
    def credit(amount_minor, on: Date.current, reason: "Returned one item")
      @invoice.issue_credit_note!(amount_minor: amount_minor, issued_on: on, reason: reason, user: users(:one))
    end

    def receivable_balance
      @ar.journal_entry_lines.sum("debit - credit")
    end
end
