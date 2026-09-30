require "test_helper"

class Accounting::InvoiceAccountResolverTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(
      name: "Resolver Customer",
      customer_type: "business",
      email: "resolver@example.com"
    )
    @receivable = Account.for_role!(@workspace, :receivable)
  end

  test "resolves saved snapshots before service mappings and the workspace default" do
    snapshot_account = create_income_account("Snapshot Income")
    changed_service_account = create_income_account("Changed Service Income")
    service_account = create_income_account("Service Income")
    default_account = create_income_account("Default Income")
    snapshot_service = @workspace.services.create!(name: "Snapshot service", income_account: snapshot_account)
    service = @workspace.services.create!(name: "Mapped service", income_account: service_account)
    @workspace.update!(default_sales_account: default_account)
    invoice = @workspace.invoices.create!(
      user: @user,
      customer: @customer,
      invoice_lines_attributes: [
        { service: snapshot_service, description: "Saved", quantity: 1, rate_minor: 100 },
        { service: service, description: "Service", quantity: 1, rate_minor: 200 },
        { description: "Default", quantity: 1, rate_minor: 300 }
      ]
    )
    saved_line, service_line, default_line = invoice.invoice_lines.to_a
    snapshot_service.update!(income_account: changed_service_account)
    service_line.update_column(:account_id, nil)
    default_line.update_column(:account_id, nil)

    result = Accounting::InvoiceAccountResolver.new.resolve(invoice.reload)

    assert result.success?, result.errors.map(&:message).to_sentence
    assert_equal @receivable.id, result.receivable_account_id
    assert_equal snapshot_account.id, result.income_account_ids.fetch(saved_line.id)
    assert_equal service_account.id, result.income_account_ids.fetch(service_line.id)
    assert_equal default_account.id, result.income_account_ids.fetch(default_line.id)
  end

  test "returns domain errors instead of creating or guessing missing accounts" do
    workspace = Workspace.create!(name: "Resolver Missing", workspace_type: "personal", currency_code: "NGN")
    customer = workspace.customers.create!(
      name: "Missing Mapping Customer",
      customer_type: "business",
      email: "missing@example.com"
    )
    invoice = workspace.invoices.create!(
      user: @user,
      customer: customer,
      invoice_lines_attributes: [ { description: "Unmapped work", quantity: 1, rate_minor: 500 } ]
    )

    assert_no_difference("Account.count") do
      result = Accounting::InvoiceAccountResolver.new.resolve(invoice)

      assert_not result.success?
      assert_equal %i[receivable_account_missing income_account_missing], result.errors.map(&:code)
      assert_includes result.errors.map(&:message), "Accounts Receivable is not configured for this workspace"
      assert_includes result.errors.last.message, "configure its service or the workspace default sales account"
    end
  end

  private
    def create_income_account(name)
      @workspace.accounts.create!(
        name: name,
        base_type: "income",
        account_type: "Personal Inflows",
        detail_type: "Side Hustle / Freelance"
      )
    end
end
