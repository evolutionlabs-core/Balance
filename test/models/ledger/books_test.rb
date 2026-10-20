require "test_helper"

class Ledger::BooksTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Books Test", currency_code: "NGN")
    @actor = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")
    @workspace.memberships.create!(user: @actor, role: :owner)
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
  end

  test "closes the ledger through the given date" do
    @ledger.close_books!(through: Date.current, actor: @actor)

    assert_equal Date.current, @ledger.reload.closed_through
    assert_equal @actor, @ledger.closed_by
    assert @ledger.closed_at.present?
  end

  test "rejects a close when the actor is not a workspace owner" do
    outsider = User.create!(full_name: "Outsider", email_address: "outsider@example.com", password: "supersecret123")

    invalid = assert_raises(ActiveRecord::RecordInvalid) do
      @ledger.close_books!(through: Date.current, actor: outsider)
    end

    assert_match /Only workspace owners/, invalid.record.errors.full_messages.to_sentence
    assert_nil @ledger.reload.closed_through
  end

  test "does not close through an earlier date than an existing close" do
    close_through(Date.current)

    invalid = assert_raises(ActiveRecord::RecordInvalid) do
      @ledger.close_books!(through: 2.weeks.ago.to_date, actor: @actor)
    end

    assert_match /already closed through/, invalid.record.errors.full_messages.to_sentence
    assert_equal Date.current, @ledger.reload.closed_through
  end

  test "extend-closing moves the boundary forward" do
    close_through(1.month.ago.to_date)

    @ledger.close_books!(through: Date.current, actor: @actor)

    assert_equal Date.current, @ledger.reload.closed_through
  end

  test "clears the closed-through boundary and its audit stamps on reopen" do
    close_through(Date.current - 1.month)

    @ledger.reopen_books!(actor: @actor)

    reloaded = @ledger.reload
    assert_nil reloaded.closed_through
    assert_nil reloaded.closed_at
    assert_nil reloaded.closed_by
  end

  test "rejects a reopen on an already-open ledger" do
    close_through(Date.current - 1.month)
    @ledger.reopen_books!(actor: @actor)

    invalid = assert_raises(ActiveRecord::RecordInvalid) do
      @ledger.reopen_books!(actor: @actor)
    end

    assert_match /already open/, invalid.record.errors.full_messages.to_sentence
  end

  test "rejects a reopen when the actor is not a workspace owner" do
    close_through(Date.current - 1.month)

    outsider = User.create!(full_name: "Outsider", email_address: "outsider@example.com", password: "supersecret123")

    invalid = assert_raises(ActiveRecord::RecordInvalid) do
      @ledger.reopen_books!(actor: outsider)
    end

    assert_match /Only workspace owners/, invalid.record.errors.full_messages.to_sentence
    assert @ledger.reload.closed_through.present?
  end

  private
    def close_through(date)
      @ledger.close_books!(through: date, actor: @actor)
    end
end
