require "test_helper"

class EmailValidatorTest < ActiveSupport::TestCase
  test "accepts ordinary addresses and blanks" do
    [ "ada@example.com", "a.b+tag@mail.example.co.uk", "" ].each do |email|
      vendor = Vendor.new(workspace: workspaces(:ada_store), name: "Paper Co", email: email)

      assert vendor.valid?, "#{email.inspect} should be valid: #{vendor.errors.full_messages.to_sentence}"
    end
  end

  test "rejects addresses without a proper domain or with spaces" do
    [ "ada", "ada@example", "ada @example.com", "@example.com", "ada@@example.com" ].each do |email|
      vendor = Vendor.new(workspace: workspaces(:ada_store), name: "Paper Co", email: email)

      assert_not vendor.valid?, "#{email.inspect} should be invalid"
      assert_includes vendor.errors[:email], "isn't a valid email address"
    end
  end
end
