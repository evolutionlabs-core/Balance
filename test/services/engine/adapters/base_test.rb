require "test_helper"

class Engine::Adapters::BaseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @workspace.provision_ledger!(template: "personal_finance")
  end

  test "requires subclasses to describe the entry" do
    adapter = Class.new(Engine::Adapters::Base).new(
      workspace: @workspace, attributes: {}, source_id: nil
    )

    assert_raises(NotImplementedError) { adapter.send(:effective_date) }
    assert_raises(NotImplementedError) { adapter.send(:action) }
    assert_raises(NotImplementedError) { adapter.send(:lines) }
  end

  test "converts a decimal amount into kobo" do
    assert_equal 4_000_000, adapter.send(:kobo, "40000.00")
    assert_equal 4_000_000, adapter.send(:kobo, 40000)
    assert_equal 4_000_000, adapter.send(:kobo, 40000.0)
  end

  test "raises a readable error when the chart has no account for the requested name" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      adapter.send(:ledger_account_for, "Fuel")
    end

    assert_equal 'No ledger account matches "Fuel" in the General ledger.', error.message
  end

  private
    def adapter
      @adapter ||= Engine::Adapters::Expense.new(workspace: @workspace, attributes: {}, source_id: nil)
    end
end
