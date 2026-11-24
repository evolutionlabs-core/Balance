require "test_helper"

class BankLinkTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "creates a link token for the current workspace" do
    workspace = users(:one).workspaces.first
    requested = nil

    Beerus.stub(:create_link_token, ->(**args) { requested = args; "lt_1" }) do
      post bank_link_token_path, as: :json
    end

    assert_response :success
    assert_equal "lt_1", response.parsed_body.fetch("link_token")
    assert_equal "workspace_#{workspace.id}", requested.fetch(:user_id)
    assert_equal bank_transactions_url, requested.fetch(:redirect_uri)
  end
end
