require "test_helper"

class Expenses::VoidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @bank = @ledger.accounts.find_by!(name: "Checking Account")
    @housing = @ledger.accounts.find_by!(name: "Housing")
    @expense = record_expense!(@workspace, payment_account: @bank, category: @housing, amount: "45000.00")
  end

  test "renders the void confirmation in the modal" do
    get new_expense_void_path(@expense)

    assert_response :success
    assert_select "turbo-frame#modal form[action=?]", expense_void_path(@expense)
  end

  test "voids the expense by reversing its entry through the engine" do
    original = @expense.journal_entry

    assert_difference -> { @ledger.journal_entries.count }, 1 do
      post expense_void_path(@expense)
    end

    assert_redirected_to expense_path(@expense)
    assert @expense.reload.voided?

    void_entry = @expense.void_entry
    assert_equal original, void_entry.reverses_entry
    assert_equal [ "Expense", @expense.id, "void" ], void_entry.values_at(:source_type, :source_id, :action)
    assert_equal Date.current, void_entry.effective_date
    assert_equal users(:one), void_entry.posted_by
    assert_equal({ @bank.id => [ 45_000_00, 0 ], @housing.id => [ 0, 45_000_00 ] },
      void_entry.journal_entry_lines.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
    assert_equal({ @housing.id => [ 45_000_00, 0 ], @bank.id => [ 0, 45_000_00 ] },
      original.journal_entry_lines.reload.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
    assert_equal original, @expense.journal_entry
  end

  test "a voided expense cannot be voided again" do
    post expense_void_path(@expense)

    assert_no_difference -> { @ledger.journal_entries.count } do
      post expense_void_path(@expense)
    end

    assert_redirected_to expense_path(@expense)
  end

  test "a void rejected by the engine leaves the expense posted" do
    @ledger.close_books!(through: Date.current, actor: users(:one))

    assert_no_difference -> { @ledger.journal_entries.count } do
      post expense_void_path(@expense)
    end

    assert_response :unprocessable_content
    assert_select "body", /Ledger is closed through #{Date.current.iso8601}/
    assert @expense.reload.posted?
  end

  test "the expense page offers a void only while posted" do
    get expense_path(@expense)
    assert_select "a[href=?]", new_expense_void_path(@expense), text: "Void"

    post expense_void_path(@expense)
    get expense_path(@expense)

    assert_select "a", text: "Void", count: 0
    assert_select "a[href=?]", journal_entry_path(@expense.reload.void_entry)
    assert_select "body", /Voided/
  end

  test "only voids expenses in the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    other = record_expense!(other_workspace, payment_account: other_workspace.payment_accounts.first,
      category: other_workspace.expense_categories.first, amount: "10.00")

    post expense_void_path(other)

    assert_response :not_found
    assert other.reload.posted?
    assert_equal 1, other_ledger.journal_entries.count
  end

  private
    def record_expense!(workspace, payment_account:, category:, amount:)
      expense = workspace.expenses.build(payment_date: Date.current, payment_account: payment_account,
        expense_lines_attributes: [ { account_id: category.id, description: "Rent", amount: amount, position: 0 } ])
      raise "expense setup failed: #{expense.errors.full_messages.to_sentence}" unless expense.record_entry!

      expense
    end
end
