require "test_helper"

class BankConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "exchanges the public token and keeps the access token for the workspace" do
    exchanged = nil

    Beerus.stub(:exchange_public_token, ->(public_token) { exchanged = public_token; "access-1" }) do
      post bank_connection_path, params: { public_token: "public-1" }, as: :json
    end

    assert_response :created
    assert_equal "public-1", exchanged

    Beerus.stub(:posted_transactions, ->(access_token) { assert_equal "access-1", access_token; [] }) do
      get bank_transactions_path
    end

    assert_select "h2", "No transactions yet"
  end
end
