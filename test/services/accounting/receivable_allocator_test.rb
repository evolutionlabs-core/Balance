require "test_helper"

class Accounting::ReceivableAllocatorTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Receipt Customer", customer_type: "business", email: "receipt@example.com")
    @other_customer = @workspace.customers.create!(name: "Other Receipt Customer", customer_type: "business", email: "other-receipt@example.com")
    @bank = Account.for_role!(@workspace, :checking)
    @receivable = Account.for_role!(@workspace, :receivable)
    @income = Account.for_role!(@workspace, :uncategorized_income)
    @service = @workspace.services.create!(name: "Receipt service", income_account: @income)
  end

  test "allocates a posted receipt to the customer's oldest invoices first" do
    oldest = post_invoice(@customer, 75_000, issue_date: Date.current - 5.days)
    newest = post_invoice(@customer, 75_000, issue_date: Date.current - 2.days)
    other = post_invoice(@other_customer, 40_000, issue_date: Date.current - 10.days)

    entry = post_receipt(@customer, 120_000)

    assert_equal [ [ oldest.id, 75_000 ], [ newest.id, 45_000 ] ],
      entry.receivable_applications.order(:id).pluck(:invoice_id, :amount_kobo)
    assert_equal 0, oldest.reload.balance_due_kobo
    assert_equal 30_000, newest.reload.balance_due_kobo
    assert_equal 40_000, other.reload.balance_due_kobo
  end

  test "leaves receipt excess unapplied" do
    invoice = post_invoice(@customer, 50_000)

    entry = post_receipt(@customer, 80_000)

    assert_equal 50_000, entry.receivable_applications.sum(:amount_kobo)
    assert_equal 0, invoice.reload.balance_due_kobo
  end

  test "does not allocate a receivable credit without a bank or cash debit" do
    invoice = post_invoice(@customer, 50_000)
    expense = Account.for_role!(@workspace, :uncategorized_expense)

    entry = @workspace.journal_entries.build(
      description: "Credit adjustment",
      entry_date: Date.current,
      journal_entry_lines_attributes: [
        { account: expense, debit_kobo: 50_000 },
        { account: @receivable, credit_kobo: 50_000, counterparty: @customer }
      ]
    )
    result = Accounting::PostingService.call(entry: entry)

    assert result.success?, result.errors.to_sentence
    assert_empty result.entry.receivable_applications
    assert_equal 50_000, invoice.reload.balance_due_kobo
  end

  test "reversing a receipt creates offset applications and restores invoice balances" do
    first = post_invoice(@customer, 60_000, issue_date: Date.current - 2.days)
    second = post_invoice(@customer, 40_000, issue_date: Date.current - 1.day)
    receipt = post_receipt(@customer, 75_000)

    reversal = receipt.reverse!

    assert_equal 2, reversal.receivable_applications.count
    assert_equal receipt.receivable_applications.order(:invoice_id).pluck(:id),
      reversal.receivable_applications.order(:invoice_id).pluck(:reverses_receivable_application_id)
    assert_equal 60_000, first.reload.balance_due_kobo
    assert_equal 40_000, second.reload.balance_due_kobo
    assert_not receipt.receivable_applications.first.update(amount_kobo: 1)
    assert_not receipt.receivable_applications.first.destroy
  end

  test "project amount owed subtracts active receipt applications" do
    project = @workspace.projects.create!(name: "Receipt project", customer: @customer)
    post_invoice(@customer, 90_000, project: project)
    post_receipt(@customer, 35_000)

    assert_equal 55_000, project.summary.amount_owed_kobo
  end

  test "rejects applications across workspaces and over the invoice balance" do
    invoice = post_invoice(@customer, 50_000)
    entry = post_receipt(@customer, 10_000)
    foreign_workspace = workspaces(:bola_shop)

    foreign = foreign_workspace.receivable_applications.build(
      invoice: invoice,
      journal_entry: entry,
      amount_kobo: 1
    )
    excessive = @workspace.receivable_applications.build(
      invoice: invoice,
      journal_entry: entry,
      amount_kobo: 50_000
    )

    assert_not foreign.valid?
    assert_includes foreign.errors[:invoice], "must belong to the workspace"
    assert_not excessive.valid?
    assert_includes excessive.errors[:amount_kobo], "cannot exceed the invoice balance"
  end

  private
    def post_invoice(customer, amount_kobo, issue_date: Date.current, project: nil)
      invoice = @workspace.invoices.create!(
        user: @user,
        customer: customer,
        project: project,
        issue_date: issue_date,
        due_date: issue_date + 30.days,
        invoice_lines_attributes: [
          { service: @service, description: "Customer work", quantity: 1, rate_minor: amount_kobo }
        ]
      )
      result = invoice.issue
      assert result.success?, result.errors.to_sentence
      invoice.reload
    end

    def post_receipt(customer, amount_kobo)
      entry = @workspace.journal_entries.build(
        description: "Customer receipt",
        entry_date: Date.current,
        journal_entry_lines_attributes: [
          { account: @bank, debit_kobo: amount_kobo },
          { account: @receivable, credit_kobo: amount_kobo, counterparty: customer }
        ]
      )
      result = Accounting::PostingService.call(entry: entry)
      assert result.success?, result.errors.to_sentence
      result.entry
    end
end
