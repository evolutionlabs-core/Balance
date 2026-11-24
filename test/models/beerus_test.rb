require "test_helper"

class BeerusTest < ActiveSupport::TestCase
  test "returns posted lines across pages, newest first, without pending lines" do
    pending = line("txn_p", status: "pending", booked_at: nil, sequence: 3)
    rent = line("txn_rent", booked_at: "2026-11-21T09:00:00+01:00", sequence: 1)
    settled = line("txn_settled", booked_at: "2026-11-23T09:00:00+01:00", sequence: 4)

    pages = {
      nil => { "added" => [ pending, rent ], "modified" => [], "removed" => [], "next_cursor" => "c1", "has_more" => true },
      "c1" => { "added" => [ settled ], "modified" => [], "removed" => [ { "id" => "txn_p" } ], "next_cursor" => "c2", "has_more" => false }
    }

    responder = lambda do |_method, path, query: {}, **|
      if path == "/v1/accounts"
        { "data" => [ { "id" => "acc_1" } ] }
      else
        assert_equal "/v1/accounts/acc_1/transactions/sync", path
        pages.fetch(query[:cursor])
      end
    end

    Beerus.stub(:request, responder) do
      assert_equal %w[txn_settled txn_rent], Beerus.posted_transactions("access-1").map { |transaction| transaction.fetch("id") }
    end
  end

  test "replaces a line when the bank modifies it" do
    original = line("txn_1", description: "TRF FRM ACME")
    corrected = line("txn_1", description: "Transfer from Acme Trading Co.")

    pages = {
      nil => { "added" => [ original ], "modified" => [], "removed" => [], "next_cursor" => "c1", "has_more" => true },
      "c1" => { "added" => [], "modified" => [ corrected ], "removed" => [], "next_cursor" => "c2", "has_more" => false }
    }

    responder = lambda do |_method, path, query: {}, **|
      if path == "/v1/accounts"
        { "data" => [ { "id" => "acc_1" } ] }
      else
        pages.fetch(query[:cursor])
      end
    end

    Beerus.stub(:request, responder) do
      assert_equal [ "Transfer from Acme Trading Co." ], Beerus.posted_transactions("access-1").map { |transaction| transaction.fetch("description") }
    end
  end

  private
    def line(id, status: "posted", booked_at: "2026-11-22T09:00:00+01:00", sequence: 1, description: "Line")
      { "id" => id, "status" => status, "booked_at" => booked_at, "sequence" => sequence, "description" => description, "amount_minor" => 100, "currency" => "NGN" }
    end
end
