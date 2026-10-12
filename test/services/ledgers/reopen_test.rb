require "test_helper"

class Ledgers::ReopenTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Reopen Test", currency_code: "NGN")
    @actor = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")
    @workspace.memberships.create!(user: @actor, role: :owner)
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    close_through(Date.current - 1.month)
  end

  test "clears the closed-through boundary and its audit stamps" do
    result = Ledgers::Reopen.call(ledger: @ledger, actor: @actor)

    assert result.ok?
    reloaded = @ledger.reload
    assert_nil reloaded.closed_through
    assert_nil reloaded.closed_at
    assert_nil reloaded.closed_by
  end

  test "rejects a reopen on an already-open ledger" do
    Ledgers::Reopen.call(ledger: @ledger, actor: @actor)

    result = Ledgers::Reopen.call(ledger: @ledger, actor: @actor)

    refute result.ok?
    assert_match /already open/, result.error
  end

  test "rejects a reopen when the actor is not a workspace owner" do
    outsider = User.create!(full_name: "Outsider", email_address: "outsider@example.com", password: "supersecret123")

    result = Ledgers::Reopen.call(ledger: @ledger, actor: outsider)

    refute result.ok?
    assert_match /Only workspace owners/, result.error
    assert @ledger.reload.closed_through.present?
  end

  private
    def close_through(date)
      close = Ledgers::Close.call(ledger: @ledger, through: date, actor: @actor)
      raise close.error unless close.ok?
    end
end
