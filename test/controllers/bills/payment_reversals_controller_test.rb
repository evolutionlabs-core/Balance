require "test_helper"

class Bills::PaymentReversalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    @bill = @workspace.bills.create!(user: users(:three), vendor: @vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: @ledger.accounts.find_by!(key: "rent").id, description: "Rent", amount: "500.00" } ])
    assert @bill.issue!
    assert @bill.record_payment!(payment_account_id: @ledger.accounts.find_by!(key: "bank").id, paid_on: Date.current, amount_kobo: 50_000)
    sign_in_as(users(:three))
  end

  test "lists the bill's payments and reverses one" do
    payment = @bill.payments.sole

    get bill_path(@bill)
    assert_select "form[action='#{bill_payment_reversal_path(@bill, payment)}'] button", "Reverse"

    post bill_payment_reversal_path(@bill, payment)

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.open?
    follow_redirect!
    assert_select "td", "Reversed"
  end
end
