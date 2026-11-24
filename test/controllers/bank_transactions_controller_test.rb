require "test_helper"

class BankTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "shows the empty state before a bank is linked" do
    get bank_transactions_path

    assert_response :success
    assert_select "h2", "No banks linked"
    assert_select "button", text: "Sync", count: 0
  end

  test "lists the linked bank's posted transactions" do
    link_bank

    Beerus.stub(:posted_transactions, ->(access_token) { assert_equal "access-1", access_token; [ transfer ] }) do
      get bank_transactions_path
    end

    assert_response :success
    assert_select "td", "Nov 23, 2026"
    assert_select "td", "Transfer from Acme Trading Co."
    assert_select "td", "+₦450,000.00"
    assert_select "button", text: "Sync"
  end

  test "says so when the bank does not respond" do
    link_bank

    Beerus.stub(:posted_transactions, ->(_access_token) { raise Beerus::Error, "Beerus responded 503" }) do
      get bank_transactions_path
    end

    assert_response :success
    assert_select "body", /Your bank isn't responding/
  end

  private
    def link_bank
      Beerus.stub(:exchange_public_token, "access-1") do
        post bank_connection_path, params: { public_token: "public-1" }, as: :json
      end
    end

    def transfer
      {
        "id" => "txn_1",
        "status" => "posted",
        "booked_at" => "2026-11-23T10:00:00+01:00",
        "description" => "Transfer from Acme Trading Co.",
        "amount_minor" => 45_000_000,
        "currency" => "NGN"
      }
    end
end
