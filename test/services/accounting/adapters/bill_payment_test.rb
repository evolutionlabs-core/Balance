require "test_helper"

class Accounting::Adapters::BillPaymentTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @bank = @ledger.accounts.find_by!(key: "bank")
    @ap = @ledger.accounts.find_by!(key: "accounts_payable")
    @vendor = @workspace.vendors.create!(name: "Paid Vendor")
  end

  test "apply debits payables and credits the payment account" do
    command = Accounting::Adapters::BillPayment.call(
      workspace: @workspace,
      attributes: { paid_on: Date.current, payment_account_id: @bank.id, amount_kobo: 12_500, vendor: @vendor },
      source_id: 3
    )

    assert_equal "BillPayment", command.source_type
    assert_equal "apply", command.action
    assert_equal Date.current, command.effective_date

    ap_line, bank_line = command.lines
    assert_equal @ap, ap_line.account
    assert_equal @vendor, ap_line.vendor
    assert_equal 12_500, ap_line.debit
    assert_equal @bank, bank_line.account
    assert_equal 12_500, bank_line.credit
  end

  test "rejects a payment account from another ledger" do
    other = workspaces(:ada_store).provision_ledger!.accounts.find_by!(key: "cash")

    assert_raises(ActiveRecord::RecordNotFound) do
      Accounting::Adapters::BillPayment.call(
        workspace: @workspace,
        attributes: { paid_on: Date.current, payment_account_id: other.id, amount_kobo: 100, vendor: @vendor },
        source_id: 3
      )
    end
  end
end
