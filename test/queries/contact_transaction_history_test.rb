require "test_helper"

class ContactTransactionHistoryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @bank = create_payment_account(@workspace)
    @fuel = create_expense_account(@workspace)
    @vendor = create_vendor(@workspace)
  end

  test "builds a row from each expense paid to the contact" do
    expense = expense_for(@vendor)

    row = ContactTransactionHistory.new(@vendor).rows.sole

    assert_equal expense, row.record
    assert_equal expense.payment_date, row.date
    assert_equal expense.total_kobo, row.amount_kobo
    assert_equal @bank, row.account
    assert_equal "draft", row.status
  end

  test "excludes expenses paid to another contact" do
    expense_for(create_vendor(@workspace, name: "Other Vendor"))

    assert_empty ContactTransactionHistory.new(@vendor).rows
  end

  test "includes draft and posted expenses" do
    draft = expense_for(@vendor)
    posted = expense_for(@vendor, payment_date: 1.day.ago.to_date)
    posted.post

    rows = ContactTransactionHistory.new(@vendor).rows

    assert_equal [ draft, posted ], rows.map(&:record)
    assert_equal %w[draft posted], rows.map(&:status)
  end

  test "orders rows from newest to oldest" do
    older = expense_for(@vendor, payment_date: 3.days.ago.to_date)
    newer = expense_for(@vendor, payment_date: Date.current)

    assert_equal [ newer, older ], ContactTransactionHistory.new(@vendor).rows.map(&:record)
  end

  test "totals posted expenses only" do
    expense_for(@vendor)
    posted = expense_for(@vendor, payment_date: 1.day.ago.to_date)
    posted.post

    assert_equal posted.total_kobo, ContactTransactionHistory.new(@vendor).posted_total_kobo
  end

  test "reports whether the contact has any activity" do
    assert_not ContactTransactionHistory.new(@vendor).any?

    expense_for(@vendor)

    assert ContactTransactionHistory.new(@vendor).any?
  end

  private
    def expense_for(contact, payment_date: Date.current)
      create_expense(@workspace,
        payee_contact: contact,
        payment_account: @bank,
        category: @fuel,
        payment_date: payment_date)
    end
end
