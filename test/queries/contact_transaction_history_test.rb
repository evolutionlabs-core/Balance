require "test_helper"

class ContactTransactionHistoryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @bank = @workspace.accounts.create!(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @fuel = @workspace.accounts.create!(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
    @vendor = create_vendor("Fuel Station")
  end

  test "builds a row from each expense paid to the contact" do
    expense = create_expense_for(@vendor)

    row = ContactTransactionHistory.new(@vendor).rows.sole

    assert_equal expense, row.record
    assert_equal expense.payment_date, row.date
    assert_equal expense.total_kobo, row.amount_kobo
    assert_equal @bank, row.account
    assert_equal "draft", row.status
  end

  test "excludes expenses paid to another contact" do
    create_expense_for(create_vendor("Other Vendor"))

    assert_empty ContactTransactionHistory.new(@vendor).rows
  end

  test "includes draft and posted expenses newest first" do
    draft = create_expense_for(@vendor)
    posted = create_expense_for(@vendor, payment_date: 1.day.ago.to_date)
    posted.post

    rows = ContactTransactionHistory.new(@vendor).rows

    assert_equal [ draft, posted ], rows.map(&:record)
    assert_equal %w[draft posted], rows.map(&:status)
  end

  test "totals posted expenses only" do
    create_expense_for(@vendor)
    posted = create_expense_for(@vendor, payment_date: 1.day.ago.to_date)
    posted.post

    assert_equal posted.total_kobo, ContactTransactionHistory.new(@vendor).posted_total_kobo
  end

  private
    def create_vendor(name)
      @workspace.contacts.create!(
        name: name,
        contact_kind: "business",
        email: "#{name.parameterize}@example.com",
        role_names: %w[vendor]
      )
    end

    def create_expense_for(contact, payment_date: Date.current)
      @workspace.expenses.create!(
        payment_date: payment_date,
        payment_account: @bank,
        payee_contact: contact,
        memo: "Generator fuel",
        expense_lines_attributes: [ { account: @fuel, description: "Fuel", amount_kobo: 4_000_000, position: 0 } ]
      )
    end
end
