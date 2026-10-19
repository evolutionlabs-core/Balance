require "test_helper"

class Bills::VoidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @bank = @ledger.accounts.find_by!(key: "bank")
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    @bill = @workspace.bills.create!(
      user: users(:three), vendor: @vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: @rent.id, description: "Office rent", amount: "500.00" } ]
    )
    sign_in_as(users(:three))
  end

  test "voids an entered bill with a reversal" do
    raise "setup failure" unless @bill.issue!

    assert_difference -> { JournalEntry.count } => 1 do
      post bill_void_path(@bill)
    end

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.voided?
  end

  test "a bill with payments cannot be voided" do
    raise "setup failure" unless @bill.issue!
    raise "setup failure" unless @bill.record_payment!(payment_account_id: @bank.id, paid_on: Date.current, amount_kobo: 100)

    post bill_void_path(@bill)

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.open?
  end
end
