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
