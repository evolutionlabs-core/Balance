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

  test "answers with a short message and keeps the bank unlinked when the exchange fails" do
    Beerus.stub(:exchange_public_token, ->(_public_token) { raise Beerus::Error, "Beerus responded 400 invalid_public_token: The public token has expired. (request req_2)" }) do
      post bank_connection_path, params: { public_token: "public-1" }, as: :json
    end

    assert_response :bad_gateway
    assert_equal "Couldn't start bank linking. Try again in a moment.", response.parsed_body.fetch("error")

    get bank_transactions_path

    assert_select "h2", "No banks linked"
  end
end
