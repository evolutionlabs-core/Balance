require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income_account = @ledger.ledger_accounts.find_by!(name: "Other Income")
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Acme Customer", email: "acme@example.com", customer_type: "business")
  end

  test "recalculates totals from quantity and rate" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 2, rate: "5000.00" } ])

    invoice.save!

    assert_equal 1_000_000, invoice.reload.total_minor
    assert_equal 1_000_000, invoice.subtotal_minor
  end

  test "requires at least one line when lines are submitted" do
    invoice = @workspace.invoices.build(user: @user, customer: @customer)
    invoice.invoice_lines_attributes = []


    invoice.valid?

    assert_includes invoice.errors[:invoice_lines], "must include at least one item"
  end

  test "requires a customer on create" do
    invoice = @workspace.invoices.build(user: @user)
    invoice.invoice_lines_attributes = [ { description: "Design", quantity: 1, rate: "5000.00" } ]


    invoice.valid?

    assert invoice.errors[:customer].any?
  end

  test "rejects a customer from another workspace" do
    foreign = workspaces(:bola_shop).customers.create!(name: "Other", email: "other@example.com", customer_type: "business")


    assert_not build_invoice(customer: foreign, lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ]).valid?
  end

  test "snapshots the income ledger account upon saving" do
    @workspace.update!(default_sales_ledger_account: @income_account)
    service = @workspace.services.create!(name: "Design", income_ledger_account: @income_account)
    invoice = build_invoice(
      lines: [
        { service_id: service.id, description: "Design", quantity: 1, rate: "10000.00" },
        { description: "Hosting", quantity: 1, rate: "2500.00" }
      ]
    )

    invoice.save!

    invoice_lines = invoice.invoice_lines.order(:position).to_a
    assert_equal @income_account.id, invoice_lines.first.ledger_account_id
    assert_equal @income_account.id, invoice_lines.last.ledger_account_id
  end

  test "content edits are allowed while draft" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!

    assert invoice.update(bill_to_name: "Renamed")
  end

  test "content edits are frozen once the invoice has left draft" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!
    invoice.send_to_client!

    assert_not invoice.update(bill_to_name: "Rebranded")
    assert_equal "Acme Customer", invoice.reload.bill_to_name
  end

  test "status-only updates skip the content freeze" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!
    invoice.send_to_client!

    assert invoice.update(status: "voided")
  end

  test "direct transitions that skip stages are rejected" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!


    assert_raises(AASM::InvalidTransition) { invoice.pay! }
  end

  test "sending when sent is rejected" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!
    invoice.send_to_client!


    assert_raises(AASM::InvalidTransition) { invoice.send_to_client! }
  end

  test "pay without full application is rejected" do
    invoice = build_invoice(lines: [ { description: "Design", quantity: 1, rate: "5000.00" } ])
    invoice.save!
    invoice.send_to_client!


    assert_raises(AASM::InvalidTransition) { invoice.pay! }
  end

  private
    def build_invoice(lines: [], **attributes)
      invoice = @workspace.invoices.build(
        { user: @user, customer: @customer, issue_date: Date.current, due_date: Date.current + 15.days,
          invoice_lines_attributes: lines }.merge(attributes)
      )
      invoice
    end
end
