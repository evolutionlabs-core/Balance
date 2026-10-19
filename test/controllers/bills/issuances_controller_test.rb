require "test_helper"

class Bills::IssuancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    @bill = @workspace.bills.create!(
      user: users(:three), vendor: @vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: @rent.id, description: "Office rent", amount: "500.00" } ]
    )
    sign_in_as(users(:three))
  end

  test "renders the confirmation" do
    get new_bill_issuance_path(@bill)

    assert_response :success
  end

  test "enters the bill and posts to payables" do
    assert_difference -> { JournalEntry.count } => 1 do
      post bill_issuance_path(@bill)
    end

    assert_redirected_to bill_path(@bill)
    assert @bill.reload.open?
  end

  test "an engine rejection re-renders the form" do
    Rule.create!(name: "block bills", severity: "block", message: "bills paused by policy")

    post bill_issuance_path(@bill)

    assert_response :unprocessable_content
    assert_match "bills paused by policy", response.body
    assert @bill.reload.draft?
  end

  test "an entered bill cannot be entered again" do
    raise "setup failure" unless @bill.issue!

    post bill_issuance_path(@bill)

    assert_redirected_to bill_path(@bill)
    assert_equal 1, JournalEntry.where(source_type: "Bill").count
  end
end
