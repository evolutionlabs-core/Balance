require "test_helper"

class UiHelperTest < ActionView::TestCase
  include UiHelper

  test "formats minor units with the currency symbol" do
    assert_equal "₦1,234.50", money(123_450, "NGN")
  end

  test "falls back to the currency code when no symbol is known" do
    assert_equal "USD 1,234.50", money(123_450, "USD")
  end

  test "defaults to the current workspace currency" do
    workspace = Workspace.new(currency_code: "GHS")
    define_singleton_method(:current_workspace) { workspace }

    assert_equal "GHS 10.00", money(1_000)
  end

  test "treats a missing amount as zero" do
    assert_equal "₦0.00", money(nil, "NGN")
  end
end
