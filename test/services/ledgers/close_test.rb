require "test_helper"

class Ledgers::CloseTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Close Test", currency_code: "NGN")
    @actor = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")
    @workspace.memberships.create!(user: @actor, role: :owner)
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
  end

  test "closes the ledger through the given date" do
    result = Ledgers::Close.call(ledger: @ledger, through: Date.current, actor: @actor)

    assert result.ok?
    assert_equal Date.current, @ledger.reload.closed_through
    assert_equal @actor, @ledger.closed_by
    assert @ledger.closed_at.present?
  end

  test "rejects a close when the actor is not a workspace owner" do
    outsider = User.create!(full_name: "Outsider", email_address: "outsider@example.com", password: "supersecret123")

    result = Ledgers::Close.call(ledger: @ledger, through: Date.current, actor: outsider)

    refute result.ok?
    assert_match /Only workspace owners/, result.error
    assert_nil @ledger.reload.closed_through
  end

  test "does not close through an earlier date than an existing close" do
    close_through(Date.current)

    result = Ledgers::Close.call(ledger: @ledger, through: 2.weeks.ago.to_date, actor: @actor)

    refute result.ok?
    assert_match /already closed through/, result.error
    assert_equal Date.current, @ledger.reload.closed_through
  end

  test "extend-closing moves the boundary forward" do
    close_through(1.month.ago.to_date)

    result = Ledgers::Close.call(ledger: @ledger, through: Date.current, actor: @actor)

    assert result.ok?
    assert_equal Date.current, @ledger.reload.closed_through
  end

  private
    def close_through(date)
      close = Ledgers::Close.call(ledger: @ledger, through: date, actor: @actor)
      raise close.error unless close.ok?
    end
end
