require "test_helper"

class Accounting::Adapters::BaseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @workspace.provision_ledger!
  end

  test "requires subclasses to describe the entry" do
    adapter = Class.new(Accounting::Adapters::Base).new(
      workspace: @workspace, attributes: {}, source_id: nil
    )

    assert_raises(NotImplementedError) { adapter.send(:effective_date) }
    assert_raises(NotImplementedError) { adapter.send(:action) }
    assert_raises(NotImplementedError) { adapter.send(:lines) }
  end

  test "raises a readable error when the chart has no account for the requested key" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      adapter.send(:account_for, "fuel")
    end

    assert_equal "No Fuel account is provisioned in the General ledger.", error.message
  end

  private
    def adapter
      @adapter ||= Accounting::Adapters::Expense.new(workspace: @workspace, attributes: {}, source_id: nil)
    end
end
