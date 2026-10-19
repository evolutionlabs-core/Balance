require "test_helper"

class Bill::PostingTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @inventory = @ledger.accounts.find_by!(key: "inventory")
    @bank = @ledger.accounts.find_by!(key: "bank")
    @ap = @ledger.accounts.find_by!(key: "accounts_payable")
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    @bill = build_bill(rent: "500.00", stock: "200.00")
  end

  test "entering a bill posts expenses against payables" do
    assert @bill.issue!
    assert_equal [ @vendor ], @ap.journal_entry_lines.map(&:vendor)

    assert @bill.reload.open?
    entry = JournalEntry.where(source_type: "Bill", source_id: @bill.id, action: "issue").sole
    lines = entry.journal_entry_lines.to_a

    assert_balanced entry
    assert_equal 50_000, lines.find { |line| line.account_id == @rent.id }.debit
    assert_equal 20_000, lines.find { |line| line.account_id == @inventory.id }.debit
    assert_equal 70_000, lines.find { |line| line.account_id == @ap.id }.credit
    assert_equal 70_000, @bill.balance_due_kobo
  end

  test "a closed period rejects entering the bill" do
    @ledger.close_books!(through: Date.current, actor: users(:three))

    assert_equal false, @bill.issue!

    assert_match(/closed through/, @bill.errors.full_messages.join)
    assert @bill.reload.draft?
  end

  test "a line charged to an ineligible account is rejected before posting" do
    @bill.bill_lines.first.update_columns(account_id: @bank.id)
    @bill.reload

    assert_equal false, @bill.issue!

    assert_match(/is not an expense or asset account/, @bill.errors.full_messages.join)
    assert @bill.reload.draft?
  end

  test "lines cannot be charged to cash, payables, or receivables" do
    %w[bank accounts_payable accounts_receivable].each do |key|
      line = @bill.bill_lines.build(account: @ledger.accounts.find_by!(key: key), description: "x", amount: "1", position: 5)

      assert_not line.valid?, "#{key} should be rejected"
      @bill.bill_lines.delete(line)
    end
  end

  test "partial payments leave the bill open and reduce the balance" do
    raise "setup failure" unless @bill.issue!

    assert @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 30_000)

    assert @bill.reload.open?
    assert_equal 40_000, @bill.balance_due_kobo
    payment = @bill.payments.sole
    entry = payment.journal_entry
    assert_balanced entry
    assert_equal "BillPayment", entry.source_type
    assert_equal 30_000, entry.journal_entry_lines.find { |line| line.account_id == @ap.id }.debit
    assert_equal 30_000, entry.journal_entry_lines.find { |line| line.account_id == @bank.id }.credit
  end

  test "paying the remaining balance marks the bill paid" do
    raise "setup failure" unless @bill.issue!

    assert @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 30_000)
    assert @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 40_000)

    assert @bill.reload.paid?
    assert_equal 0, @bill.balance_due_kobo
  end

  test "overpayment is refused without posting" do
    raise "setup failure" unless @bill.issue!

    assert_no_difference -> { JournalEntry.count } do
      assert_equal false, @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 70_001)
    end

    assert_match(/no more than the balance due/, @bill.errors.full_messages.join)
    assert_empty @bill.payments.reload
  end

  test "a draft bill cannot be paid" do
    assert_equal false, @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 100)

    assert @bill.reload.draft?
    assert_empty BillPayment.all
  end

  test "a payment account must be cash or credit card" do
    raise "setup failure" unless @bill.issue!

    assert_equal false, @bill.record_payment!(payment_account_id: @rent.id, paid_on: Date.current, amount_kobo: 100)

    assert_match(/cash or credit-card/, @bill.errors.full_messages.join)
  end

  test "a payment rejected by the engine rolls back the application" do
    raise "setup failure" unless @bill.issue!

    assert_no_difference -> { BillPayment.count } do
      assert_equal false, @bill.record_payment!(payment_account_id: @bank.id, paid_on: nil, amount_kobo: 100)
    end

    assert @bill.reload.open?
  end

  test "voiding an unpaid bill reverses its issue entry" do
    raise "setup failure" unless @bill.issue!

    assert @bill.void!

    assert @bill.reload.voided?
    issue = JournalEntry.find_by!(source_type: "Bill", source_id: @bill.id, action: "issue")
    void = JournalEntry.find_by!(source_type: "Bill", source_id: @bill.id, action: "void")
    assert_equal issue, void.reverses_entry
    assert_balanced void
    assert_equal 0, ap_balance
  end

  test "voiding a draft bill posts nothing" do
    assert_no_difference -> { JournalEntry.count } do
      assert @bill.void!
    end

    assert @bill.reload.voided?
  end

  test "a bill with payments cannot be voided" do
    raise "setup failure" unless @bill.issue!
    assert @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 100)

    assert_equal false, @bill.void!

    assert @bill.reload.open?
  end

  test "entered bills cannot be edited" do
    raise "setup failure" unless @bill.issue!

    assert_equal false, @bill.update(notes: "changed")
    assert_nil @bill.reload.notes
  end

  test "bills are business-only" do
    personal = workspaces(:ada_store)
    vendor = personal.vendors.create!(name: "Shop")
    bill = personal.bills.build(user: users(:one), vendor: vendor)

    assert_not bill.valid?
    assert_includes bill.errors.full_messages, "Bills are only available in business workspaces"
  end

  test "the payables control account equals the sum of open bill balances" do
    paid_down = build_bill(rent: "400.00")
    settled = build_bill(stock: "150.00")
    voided = build_bill(rent: "90.00")
    draft = build_bill(rent: "999.00")

    [ @bill, paid_down, settled, voided ].each { |bill| raise "setup failure" unless bill.issue! }
    assert paid_down.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 15_000)
    assert settled.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 15_000)
    assert voided.void!

    assert settled.reload.paid?
    assert draft.reload.draft?
    JournalEntry.where(ledger: @ledger).find_each { |entry| assert_balanced entry }

    open_balances = @workspace.bills.reload.outstanding.sum(&:balance_due_kobo)
    assert_equal 70_000 + 25_000, open_balances
    assert_equal open_balances, ap_balance
  end

  private
    def build_bill(rent: nil, stock: nil)
      lines = []
      lines << { account_id: @rent.id, description: "Office rent", amount: rent } if rent
      lines << { account_id: @inventory.id, description: "Stock", amount: stock } if stock

      @workspace.bills.create!(user: users(:three), vendor: @vendor, bill_date: Date.current, bill_lines_attributes: lines)
    end

    def ap_balance
      lines = JournalEntryLine.where(account: @ap)
      lines.sum(:credit) - lines.sum(:debit)
    end

    def assert_balanced(entry)
      lines = entry.journal_entry_lines.reload
      assert_equal lines.sum(&:debit), lines.sum(&:credit), "entry #{entry.id} is unbalanced"
      assert lines.sum(&:debit).positive?
    end
end
