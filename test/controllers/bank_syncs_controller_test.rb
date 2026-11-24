require "test_helper"

class BankSyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))

    Beerus.stub(:exchange_public_token, "access-1") do
      post bank_connection_path, params: { public_token: "public-1" }, as: :json
    end
  end

  test "asks the bank for fresh data" do
    refreshed = nil

    Beerus.stub(:refresh, ->(access_token) { refreshed = access_token }) do
      post bank_sync_path
    end

    assert_redirected_to bank_transactions_path
    assert_equal "access-1", refreshed
  end

  test "says so when the sync fails" do
    Beerus.stub(:refresh, ->(_access_token) { raise Beerus::Error, "Beerus responded 429" }) do
      post bank_sync_path
    end

    assert_redirected_to bank_transactions_path
    assert_equal "Couldn't sync. Try again in a moment.", flash[:alert]
  end
end
