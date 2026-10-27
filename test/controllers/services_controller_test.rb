require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @income_account = @ledger.accounts.find_by!(name: "Other Income")
  end

  test "lists only current workspace services" do
    visible = @workspace.services.create!(name: "Visible service", income_account: @income_account)
    other_ledger = provision_business_ledger!(workspaces(:bola_shop))
    workspaces(:bola_shop).services.create!(
      name: "Hidden service", income_account: other_ledger.accounts.find_by!(name: "Sales")
    )

    get services_path

    assert_response :success
    assert_select "tr##{dom_id(visible)}"
    assert_select "body", text: /Hidden service/, count: 0
  end

  test "index shows 20 services per page" do
    services = (1..21).map { |number| @workspace.services.create!(name: format("Coaching session %02d", number), income_account: @income_account) }

    get services_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{services_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get services_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tr##{dom_id(services.last)}"
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index hides pagination when every service fits on one page" do
    @workspace.services.create!(name: "Scouting report", income_account: @income_account)

    get services_path

    assert_select "nav[aria-label=Pagination]", count: 0
  end

  test "creates a service" do
    assert_difference("@workspace.services.count", 1) do
      post services_path, params: { service: {
        name: "Furniture sourcing", description: "Source furniture", default_rate: "5000",
        income_account_id: @income_account.id
      } }
    end

    service = @workspace.services.order(:id).last
    assert_redirected_to services_path
    assert_equal 500_000, service.default_rate_minor
    assert service.active?
  end

  test "renders invalid creation" do
    assert_no_difference("Service.count") do
      post services_path, params: { service: { name: "Missing account" } }
    end

    assert_response :unprocessable_content
    assert_select "#modal", text: /Income account must exist/
  end

  test "updates and deactivates a service" do
    service = @workspace.services.create!(name: "Old name", income_account: @income_account)

    patch service_path(service), params: { service: {
      name: "New name", income_account_id: @income_account.id, active: "0"
    } }

    assert_redirected_to services_path
    assert_equal "New name", service.reload.name
    assert_not service.active?
  end

  test "cannot update another workspace service" do
    other_ledger = provision_business_ledger!(workspaces(:bola_shop))
    service = other_ledger.workspace.services.create!(
      name: "Foreign service", income_account: other_ledger.accounts.find_by!(name: "Sales")
    )

    patch service_path(service), params: { service: { name: "Hijacked" } }

    assert_response :not_found
    assert_equal "Foreign service", service.reload.name
  end
end
