require "test_helper"

class BillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    sign_in_as(users(:three))
  end

  test "lists bills" do
    create_bill

    get bills_path

    assert_response :success
    assert_match "Lagos Landlords", response.body
  end

  test "index shows 20 bills per page" do
    bills = (1..21).map { |number| create_bill(bill_number: format("KIT-%02d", number)) }

    get bills_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{bills_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get bills_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tr##{dom_id(bills.first)}"
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index shows pagination with both directions disabled when every bill fits on one page" do
    create_bill

    get bills_path

    assert_select "nav[aria-label=Pagination]", text: /\A\s*1–/ do
      assert_select "span[aria-disabled=true]", text: "Previous"
      assert_select "span[aria-disabled=true]", text: "Next"
      assert_select "a", count: 0
    end
  end

  test "renders the new bill form" do
    get new_bill_path

    assert_response :success
  end

  test "creates a draft bill without posting" do
    assert_difference -> { @workspace.bills.count } => 1 do
      assert_no_difference -> { JournalEntry.count } do
        post bills_path, params: { bill: bill_params }
      end
    end

    bill = @workspace.bills.last
    assert_redirected_to bill_path(bill)
    assert bill.draft?
    assert_equal 50_000, bill.total_kobo
  end

  test "rejects a bill without lines" do
    assert_no_difference -> { Bill.count } do
      post bills_path, params: { bill: bill_params.merge(bill_lines_attributes: { "0" => { description: "", amount: "", account_id: "" } }) }
    end

    assert_response :unprocessable_content
  end

  test "updates a draft bill" do
    bill = create_bill

    patch bill_path(bill), params: { bill: { bill_number: "LL-2" } }

    assert_redirected_to bill_path(bill)
    assert_equal "LL-2", bill.reload.bill_number
  end

  test "renders the edit form for a draft bill" do
    bill = create_bill

    get edit_bill_path(bill)

    assert_response :success
    assert_match "Office rent", response.body
    assert_match "500.0", response.body
  end

  test "each saved line carries its id and destroy flag inside its removable row" do
    bill = create_bill

    get edit_bill_path(bill)

    line = bill.bill_lines.sole
    assert_select "[data-amount-lines-target='lines'] [data-amount-lines-target='row']", count: 1 do
      assert_select "input[type='hidden'][name$='[id]'][value='#{line.id}']"
      assert_select "input[type='hidden'][name$='[_destroy]']"
    end
    assert_select "input[name$='[id]']", count: 1
  end

  test "updating a draft changes one line and removes another" do
    bill = create_bill
    utilities = @ledger.accounts.find_by!(key: "utilities")
    bill.bill_lines.create!(account: utilities, description: "Power", amount: "80.00", position: 1)
    rent_line, power_line = bill.bill_lines.reload.to_a

    patch bill_path(bill), params: { bill: { bill_lines_attributes: {
      "0" => { id: rent_line.id, account_id: @rent.id, description: "Office rent", amount: "450.00", position: 0 },
      "1" => { id: power_line.id, account_id: utilities.id, description: "Power", amount: "80.00", position: 1, _destroy: "1" }
    } } }

    assert_redirected_to bill_path(bill)
    bill.reload
    assert_equal 45_000, bill.total_kobo
    assert_equal [ rent_line.id ], bill.bill_lines.pluck(:id)
  end

  test "an entered bill cannot be edited" do
    bill = create_bill
    raise "setup failure" unless bill.issue!

    get edit_bill_path(bill)

    assert_redirected_to bill_path(bill)
  end

  test "shows a bill" do
    get bill_path(create_bill)

    assert_response :success
    assert_match "Office rent", response.body
  end

  test "personal workspaces are redirected away" do
    sign_out
    sign_in_as(users(:one))

    get bills_path

    assert_redirected_to root_path
  end

  private
    def bill_params
      {
        vendor_id: @vendor.id, bill_number: "LL-1", bill_date: Date.current.to_s,
        bill_lines_attributes: { "0" => { account_id: @rent.id, description: "Office rent", amount: "500.00", position: 0 } }
      }
    end

    def create_bill(bill_number: nil)
      @workspace.bills.create!(
        user: users(:three), vendor: @vendor, bill_number: bill_number, bill_date: Date.current,
        bill_lines_attributes: [ { account_id: @rent.id, description: "Office rent", amount: "500.00" } ]
      )
    end
end
