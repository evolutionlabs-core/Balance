require "test_helper"

class VendorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @workspace.provision_ledger!
    sign_in_as(users(:three))
  end

  test "lists vendors" do
    @workspace.vendors.create!(name: "Lagos Landlords")

    get vendors_path

    assert_response :success
    assert_match "Lagos Landlords", response.body
  end

  test "index shows 20 vendors per page" do
    vendors = (1..21).map { |number| @workspace.vendors.create!(name: format("Kit Supplier %02d", number)) }

    get vendors_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{vendors_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get vendors_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", vendor_path(vendors.last)
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index hides pagination when every vendor fits on one page" do
    @workspace.vendors.create!(name: "Touchline Kits")

    get vendors_path

    assert_select "nav[aria-label=Pagination]", count: 0
  end

  test "creates a vendor" do
    assert_difference -> { @workspace.vendors.count } => 1 do
      post vendors_path, params: { vendor: { name: "Ikeja Paper", email: "sales@ikeja.test", active: "1" } }
    end

    assert_redirected_to vendors_path
  end

  test "rejects a vendor without a name" do
    assert_no_difference -> { Vendor.count } do
      post vendors_path, params: { vendor: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "rejects a phone number with letters" do
    assert_no_difference -> { Vendor.count } do
      post vendors_path, params: { vendor: { name: "Ikeja Paper", phone: "jxksa" } }
    end

    assert_response :unprocessable_content
    assert_select "#phone_error", text: "Phone can only contain numbers, spaces, +, - and brackets"
    assert_select "input#vendor_phone[class*='border-red-500']"
  end

  test "updates a vendor" do
    vendor = @workspace.vendors.create!(name: "Old name")

    patch vendor_path(vendor), params: { vendor: { name: "New name" } }

    assert_redirected_to vendors_path
    assert_equal "New name", vendor.reload.name
  end

  test "shows a vendor with its bills" do
    vendor = @workspace.vendors.create!(name: "Lagos Landlords")

    get vendor_path(vendor)

    assert_response :success
    assert_match "Outstanding", response.body
  end

  test "cannot reach another workspace's vendor" do
    other = workspaces(:bola_shop).vendors.create!(name: "Elsewhere")

    get vendor_path(other)

    assert_response :not_found
  end

  test "personal workspaces are redirected away" do
    sign_out
    sign_in_as(users(:one))

    get vendors_path

    assert_redirected_to root_path
  end
end
