require "test_helper"

class InvoiceReceiptsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Receipt Customer", customer_type: "business", email: "invoice-receipt@example.com")
    @bank = Account.for_role!(@workspace, :checking)
    @receivable = Account.for_role!(@workspace, :receivable)
    income = Account.for_role!(@workspace, :uncategorized_income)
    service = @workspace.services.create!(name: "Receipt work", income_account: income)
    @invoice = @workspace.invoices.create!(
      user: @user,
      customer: @customer,
      issue_date: Date.current,
      due_date: Date.current + 30.days,
      invoice_lines_attributes: [ { service: service, description: "Work", quantity: 1, rate_minor: 100_000 } ]
    )
    assert @invoice.issue.success?
  end

  test "new offers only workspace Bank or Cash accounts" do
    investment = @workspace.accounts.create!(name: "Investment", base_type: "asset",
      account_type: "Investments & Long-Term Assets", detail_type: "Taxable Brokerage")

    get new_invoice_receipt_path(@invoice)

    assert_response :success
    assert_select "#modal dialog", text: /Invoice paid/
    assert_select "select[name='invoice_receipt[account_id]'] option", text: @bank.name
    assert_select "select[name='invoice_receipt[account_id]'] option", text: investment.name, count: 0
    assert_select "input[name='invoice_receipt[amount]'][value='1000.00']"
  end

  test "create posts cash against receivables without touching income" do
    received_on = Date.current - 2.days

    assert_difference [ "JournalEntry.count", "ReceivableApplication.count" ], 1 do
      post invoice_receipt_path(@invoice), params: {
        invoice_receipt: { account_id: @bank.id, received_on: received_on, amount: "1000.00" }
      }
    end

    assert_redirected_to invoice_path(@invoice)
    assert_match(/Payment recorded/, flash[:notice])
    receipt = JournalEntry.order(:id).last
    assert_equal received_on, receipt.entry_date
    assert_equal "Payment received for invoice #{@invoice.invoice_number}", receipt.description
    assert_equal [ [ @bank.id, 100_000, 0 ], [ @receivable.id, 0, 100_000 ] ].sort,
      receipt.journal_entry_lines.map { |line| [ line.account_id, line.debit_kobo, line.credit_kobo ] }.sort
    assert_equal [ @customer ], receipt.journal_entry_lines.select { |line| line.credit_kobo.positive? }.map(&:counterparty)
    assert_equal 0, @invoice.reload.balance_due_kobo
  end

  test "create preserves partial payments" do
    post invoice_receipt_path(@invoice), params: {
      invoice_receipt: { account_id: @bank.id, received_on: Date.current, amount: "400.00" }
    }

    assert_redirected_to invoice_path(@invoice)
    assert_equal 40_000, @invoice.reload.applied_amount_kobo
    assert_equal 60_000, @invoice.balance_due_kobo
  end

  test "create rejects accounts outside the workspace and amounts above the balance" do
    foreign_bank = Account.for_role!(workspaces(:bola_shop), :checking)

    assert_no_difference [ "JournalEntry.count", "ReceivableApplication.count" ] do
      post invoice_receipt_path(@invoice), params: {
        invoice_receipt: { account_id: foreign_bank.id, received_on: Date.current, amount: "1001.00" }
      }
    end

    assert_response :unprocessable_content
    assert_select "#modal", text: /Bank or Cash account/
    assert_select "#modal", text: /no more than the balance due/
  end

  test "draft and fully paid invoices cannot receive another payment" do
    draft = @workspace.invoices.create!(user: @user, customer: @customer)

    get new_invoice_receipt_path(draft)
    assert_redirected_to invoice_path(draft)

    post invoice_receipt_path(@invoice), params: {
      invoice_receipt: { account_id: @bank.id, received_on: Date.current, amount: "1000.00" }
    }
    assert_no_difference("JournalEntry.count") do
      get new_invoice_receipt_path(@invoice)
    end
    assert_redirected_to invoice_path(@invoice)
  end

  test "receipt allocation prioritizes the invoice where payment was recorded" do
    older_invoice = @workspace.invoices.create!(
      user: @user,
      customer: @customer,
      issue_date: Date.current - 10.days,
      invoice_lines_attributes: [
        { service: @invoice.invoice_lines.first.service, description: "Older work", quantity: 1, rate_minor: 50_000 }
      ]
    )
    assert older_invoice.issue.success?

    post invoice_receipt_path(@invoice), params: {
      invoice_receipt: { account_id: @bank.id, received_on: Date.current, amount: "1000.00" }
    }

    assert_equal 0, @invoice.reload.balance_due_kobo
    assert_equal 50_000, older_invoice.reload.balance_due_kobo
  end
end
