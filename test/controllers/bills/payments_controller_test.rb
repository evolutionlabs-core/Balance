require "test_helper"

class Bills::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @bank = @ledger.accounts.find_by!(key: "bank")
    @ap = @ledger.accounts.find_by!(key: "accounts_payable")
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    @bill = @workspace.bills.create!(
      user: users(:three), vendor: @vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: @rent.id, description: "Office rent", amount: "500.00" } ]
    )
    raise "setup failure" unless @bill.issue!
    sign_in_as(users(:three))
  end

  test "renders the payment form" do
    get new_bill_payment_path(@bill)

    assert_response :success
  end

  test "records a full payment and settles the bill" do
    assert_difference -> { JournalEntry.count } => 1, -> { BillPayment.count } => 1 do
      post bill_payment_path(@bill), params: payment_params
    end

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.paid?

    lines = @bill.payments.sole.journal_entry.journal_entry_lines.to_a
    assert_equal @ap.id, lines.find { |line| line.debit.positive? }.account_id
    assert_equal @bank.id, lines.find { |line| line.credit.positive? }.account_id
  end

  test "partial payments keep the bill open" do
    post bill_payment_path(@bill), params: payment_params(amount: "125.00")

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.open?
    assert_equal 37_500, @bill.balance_due_kobo
  end

  test "overpayments are refused with the form" do
    assert_no_difference -> { BillPayment.count } do
      post bill_payment_path(@bill), params: payment_params(amount: "500.01")
    end

    assert_response :unprocessable_content
  end

  test "a paid bill redirects away from the payment form" do
    raise "setup failure" unless @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 50_000)

    get new_bill_payment_path(@bill)

    assert_redirected_to bill_path(@bill)
  end

  private
    def payment_params(amount: "500.00")
      { bill_payment: { payment_account_id: @bank.id, paid_on: Date.current.to_s, amount: amount } }
    end
end
