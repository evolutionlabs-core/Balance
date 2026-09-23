require "test_helper"

class InvoicePostingsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @customer = @workspace.customers.create!(name: "Posting Customer", customer_type: "business", email: "posting@example.com")
    @receivable = Account.for_role!(@workspace, :receivable)
    @revenue = @workspace.accounts.create!(name: "Posting Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @service = @workspace.services.create!(name: "Posting service", income_account: @revenue)
  end

  test "new shows each line income account without an accounts receivable picker" do
    invoice = create_invoice

    get new_invoice_posting_path(invoice)

    assert_response :success
    assert_select "#modal dialog", text: /Issue invoice/
    assert_select "#modal select[name='receivable_account_id']", count: 0
    assert_select "#modal select[name='revenue_account_id']", count: 0
    assert_select "#modal select[name='invoice[invoice_lines_attributes][0][account_id]'] option[selected]", text: @revenue.name
  end

  test "create posts the invoice and redirects with a notice" do
    invoice = create_invoice

    assert_difference("JournalEntry.count", 1) do
      post invoice_posting_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/issued/, flash[:notice])
    assert invoice.reload.posted?
    assert_equal @revenue, invoice.invoice_lines.first.account
  end

  test "create rejects an invalid line account" do
    invoice = create_invoice
    expense_account = @workspace.accounts.create!(name: "Posting Materials", base_type: "expense",
      account_type: "Personal Outflows", detail_type: "Transportation")

    invoice.invoice_lines.first.update_column(:account_id, expense_account.id)

    assert_no_difference("JournalEntry.count") { post invoice_posting_path(invoice) }

    assert_response :unprocessable_content
    assert_select "#modal", text: /workspace income/
    assert invoice.reload.draft?
  end

  test "posting is scoped to the current workspace" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Other", customer_type: "single", email: "o@example.com")
    other_invoice = other_workspace.invoices.create!(user: @user, customer: other_customer)

    get new_invoice_posting_path(other_invoice)
    assert_response :not_found

    post invoice_posting_path(other_invoice)
    assert_response :not_found
  end

  test "posted invoices cannot be posted again" do
    invoice = create_invoice
    post invoice_posting_path(invoice)

    assert_no_difference("JournalEntry.count") do
      post invoice_posting_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert invoice.reload.posted?
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user, customer: @customer,
        issue_date: Date.current, due_date: Date.current + 15.days,
        invoice_lines_attributes: { "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" } }
      )
    end
end
