require "test_helper"

class PhoneValidatorTest < ActiveSupport::TestCase
  test "accepts common local and international formats" do
    [ "08031234567", "+234 803 123 4567", "+1 (415) 555-0123", "020.7946.0958", "" ].each do |phone|
      vendor = Vendor.new(workspace: workspaces(:ada_store), name: "Paper Co", phone: phone)

      assert vendor.valid?, "#{phone.inspect} should be valid: #{vendor.errors.full_messages.to_sentence}"
    end
  end

  test "rejects letters and other symbols" do
    [ "jxksa", "0803-CALL-NOW", "0803#123456", "phone: 0803123" ].each do |phone|
      vendor = Vendor.new(workspace: workspaces(:ada_store), name: "Paper Co", phone: phone)

      assert_not vendor.valid?, "#{phone.inspect} should be invalid"
      assert_includes vendor.errors[:phone], "can only contain numbers, spaces, +, - and brackets"
    end
  end

  test "rejects numbers that are too short or too long" do
    [ "12345", "+1234567890123456" ].each do |phone|
      vendor = Vendor.new(workspace: workspaces(:ada_store), name: "Paper Co", phone: phone)

      assert_not vendor.valid?
      assert_includes vendor.errors[:phone], "should have between 7 and 15 digits"
    end
  end
end
