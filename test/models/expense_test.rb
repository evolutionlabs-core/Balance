require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @bank = create_account(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @fuel = create_account(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "derives a balanced journal entry from expense meaning" do
    expense = build_expense
    entry = expense.journal_entry_draft

    assert_equal 2, entry.journal_entry_lines.size
    assert_equal [ @fuel.id, 4_000_000, 0 ], line_signature(entry.journal_entry_lines.first)
    assert_equal [ @bank.id, 0, 4_000_000 ], line_signature(entry.journal_entry_lines.second)
    assert Accounting::Engine.check(entry.journal_entry_lines).ok?
  end

  test "uses the expense memo as the journal entry description" do
    expense = build_expense(memo: "Generator fuel")

    assert_equal "Generator fuel", expense.journal_entry_draft.description
  end

  test "stores the total used for duplicate detection" do
    expense = build_expense

    expense.save!

    assert_equal 4_000_000, expense.total_kobo
  end

  test "finds another expense with the same date and total" do
    original = build_expense
    original.save!
    candidate = build_expense
    candidate.save!

    assert_includes candidate.possible_duplicates, original
  end

  test "does not flag expenses with different totals as duplicates" do
    original = build_expense
    original.save!
    candidate = build_expense
    candidate.expense_lines.first.amount_kobo = 5_000_000
    candidate.save!

    assert_not_includes candidate.possible_duplicates, original
  end

  test "supports split category lines" do
    uniforms = create_account(name: "Uniforms", base_type: "expense", account_type: "Personal Outflows", detail_type: "Living & Daily Needs")
    expense = build_expense
    expense.expense_lines.build(account: uniforms, description: "Uniform", amount_kobo: 1_000_000, position: 1)

    entry = expense.journal_entry_draft

    assert_equal 3, entry.journal_entry_lines.size
    assert_equal 5_000_000, expense.total_kobo
    assert_equal 5_000_000, entry.journal_entry_lines.last.credit_kobo
    assert_equal "Fuel and Uniform", expense.description
    assert_equal "Fuel and Uniforms", expense.category_label
  end

  test "rejects an ineligible payment account" do
    loan = create_account(name: "Loan", base_type: "liability", account_type: "Short-Term Debt", detail_type: "Short-Term Loans")
    expense = build_expense(payment_account: loan)

    assert_not expense.valid?
    assert_includes expense.errors[:payment_account], "must be an asset or credit-card account"
  end

  test "accepts payment accounts identified by the workspace catalog" do
    credit_card = create_account(name: "Card", base_type: "liability", account_type: "Short-Term Debt", detail_type: "Credit Cards")

    assert build_expense(payment_account: credit_card).valid?
  end

  test "rejects payment dates too far in the past" do
    expense = build_expense
    expense.payment_date = 10.years.ago.to_date - 1.day

    assert_not expense.valid?
    assert_includes expense.errors[:payment_date], "is too far in the past"
  end

  test "rejects an ineligible category account" do
    income = create_account(name: "Salary", base_type: "income", account_type: "Personal Inflows", detail_type: "Earned Salary & Wages")
    expense = build_expense(category: income)

    assert_not expense.valid?
    assert_includes expense.expense_lines.first.errors[:account], "is not an eligible expense category"
  end

  test "posts and links the expense atomically" do
    expense = build_expense
    expense.save!

    assert_difference("JournalEntry.count", 1) do
      assert_difference("JournalEntryLine.count", 2) do
        result = expense.post
        assert result.success?, result.errors.to_sentence
      end
    end

    assert expense.reload.posted?
    assert_equal expense.journal_entry.workspace, @workspace
    assert_equal 2, expense.journal_entry.journal_entry_lines.count
  end

  test "builds the posted entry from locked current expense lines" do
    expense = build_expense
    expense.save!
    expense.expense_lines.load
    Expense.find(expense.id).update!(expense_lines_attributes: [
      { id: expense.expense_lines.first.id, amount: "50000.00", position: 0 }
    ])

    result = expense.post

    assert result.success?, result.errors.to_sentence
    assert_equal 5_000_000, result.entry.journal_entry_lines.find_by(account: @fuel).debit_kobo
    assert_equal 5_000_000, result.entry.journal_entry_lines.find_by(account: @bank).credit_kobo
  end

  test "rejects non-finite and sub-kobo amount input" do
    expense = build_expense
    line = expense.expense_lines.first

    line.amount = "NaN"
    assert_not expense.valid?
    assert_includes line.errors[:amount], "must be a valid number"

    line.amount = "1.999"
    assert_not expense.valid?
    assert_includes line.errors[:amount], "must be a valid number"
  end

  test "cannot be posted twice" do
    expense = build_expense
    expense.save!
    assert expense.post.success?

    assert_no_difference("JournalEntry.count") do
      result = expense.post
      assert_not result.success?
      assert_includes result.errors, "has already been posted"
    end
  end

  test "posted expense lines are immutable" do
    expense = build_expense
    expense.save!
    assert expense.post.success?
    line = expense.expense_lines.first

    assert_not line.update(description: "Changed")
    assert_equal "Fuel", line.reload.description
  end

  private
    def create_account(**attributes)
      @workspace.accounts.create!(attributes)
    end

    def build_expense(payment_account: @bank, category: @fuel, memo: nil, payment_date: Date.current)
      @workspace.expenses.build(
        payment_date: payment_date,
        payment_account: payment_account,
        memo: memo,
        expense_lines_attributes: [
          { account: category, description: "Fuel", amount_kobo: 4_000_000, position: 0 }
        ]
      )
    end

    def line_signature(line)
      [ line.account_id, line.debit_kobo, line.credit_kobo ]
    end
end
