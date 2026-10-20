require "test_helper"

class MoneyInputTest < ActiveSupport::TestCase
  test "reads naira amounts into kobo" do
    assert_equal 125_000, MoneyInput.to_kobo("1,250")
    assert_equal 125_050, MoneyInput.to_kobo("₦1,250.50")
    assert_equal 500, MoneyInput.to_kobo(" 5 ")
  end

  test "rejects malformed and negative amounts" do
    [ "1.2.3", "-50", "NaN", "Infinity", "abc", "", "1.234" ].each do |input|
      assert_nil MoneyInput.to_kobo(input), "#{input.inspect} should be rejected"
    end
  end
end
