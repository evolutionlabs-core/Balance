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

  test "sends the configured redirect URI when one is set" do
    requested = nil

    with_env("BEERUS_REDIRECT_URI" => "http://localhost:8080/bank_transactions") do
      Beerus.stub(:create_link_token, ->(**args) { requested = args; "lt_1" }) do
        post bank_link_token_path, as: :json
      end
    end

    assert_equal "http://localhost:8080/bank_transactions", requested.fetch(:redirect_uri)
  end

  test "answers with a short message when Beerus refuses" do
    failure = ->(**) { raise Beerus::Error, "Beerus responded 400 invalid_request: redirect_uri must exactly match a registered redirect URI. (request req_1)" }

    Beerus.stub(:create_link_token, failure) do
      post bank_link_token_path, as: :json
    end

    assert_response :bad_gateway
    assert_equal "Couldn't start bank linking. Try again in a moment.", response.parsed_body.fetch("error")
  end

  private
    def with_env(values)
      previous = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
