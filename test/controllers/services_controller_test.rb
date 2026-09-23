require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @income_account = @workspace.accounts.create!(name: "Services Controller Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
  end

  test "lists only current workspace services" do
    visible = @workspace.services.create!(name: "Visible service", income_account: @income_account)
    other_workspace = workspaces(:bola_shop)
    foreign_account = other_workspace.accounts.create!(name: "Other Service Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    other_workspace.services.create!(name: "Hidden service", income_account: foreign_account)

    get services_path

    assert_response :success
    assert_select "tr##{dom_id(visible)}"
    assert_select "body", text: /Hidden service/, count: 0
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
    other_workspace = workspaces(:bola_shop)
    foreign_account = other_workspace.accounts.create!(name: "Foreign Service Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    service = other_workspace.services.create!(name: "Foreign service", income_account: foreign_account)

    patch service_path(service), params: { service: { name: "Hijacked" } }

    assert_response :not_found
    assert_equal "Foreign service", service.reload.name
  end
end
