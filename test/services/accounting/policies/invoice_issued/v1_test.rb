require "test_helper"

class Accounting::Policies::InvoiceIssued::V1Test < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(
      name: "Policy Customer",
      customer_type: "business",
      email: "policy@example.com"
    )
    @receivable = Account.for_role!(@workspace, :receivable)
    @income = @workspace.accounts.create!(
      name: "Policy Income",
      base_type: "income",
      account_type: "Personal Inflows",
      detail_type: "Side Hustle / Freelance"
    )
    @service = @workspace.services.create!(name: "Policy service", income_account: @income)
  end

  test "builds an immutable posting plan without invoking the engine or writing" do
    invoice = create_invoice
    invoice_attributes = invoice.attributes
    line_attributes = invoice.invoice_lines.map(&:attributes)

    Accounting::Engine.stub(:check, ->(*) { flunk("the policy must not invoke the ledger engine") }) do
      assert_no_difference([ "JournalEntry.count", "JournalEntryLine.count" ]) do
        result = Accounting::Policies::InvoiceIssued::V1.call(invoice:)

        assert result.success?, result.errors.map(&:message).to_sentence
        assert_equal @workspace.id, result.plan.workspace_id
        assert_equal Date.current, result.plan.entry_date
        assert_equal "Invoice #{invoice.invoice_number}", result.plan.description
        assert_equal [
          [ @income.id, 0, 30_000, nil, nil ],
          [ @income.id, 0, 5_000, nil, nil ],
          [ @receivable.id, 35_000, 0, "Customer", @customer.id ]
        ], result.plan.lines.map { |line|
          [ line.account_id, line.debit_kobo, line.credit_kobo, line.counterparty_type, line.counterparty_id ]
        }
        assert_predicate result.plan, :frozen?
        assert_predicate result.plan.lines, :frozen?
      end
    end

    assert_equal invoice_attributes, invoice.reload.attributes
    assert_equal line_attributes, invoice.invoice_lines.map(&:attributes)
    assert invoice.draft?
    assert_nil invoice.journal_entry
  end

  test "standalone and estimate-converted invoices produce the same posting shape" do
    standalone = create_invoice
    project = @workspace.projects.create!(customer: @customer, name: "Policy Project")
    estimate = @workspace.estimates.create!(
      user: @user,
      customer: @customer,
      project: project,
      line_items_attributes: [
        { service: @service, description: "Consulting", quantity: 2, rate_minor: 15_000 },
        { service: @service, description: "Support", quantity: 1, rate_minor: 5_000 }
      ]
    )
    estimate.send_to_client!
    estimate.approve!
    converted = estimate.build_invoice(user: @user)
    converted.save!
    estimate.convert_to_invoice!

    standalone_plan = Accounting::Policies::InvoiceIssued::V1.call(invoice: standalone).plan
    converted_plan = Accounting::Policies::InvoiceIssued::V1.call(invoice: converted).plan

    assert_equal posting_signature(standalone_plan), posting_signature(converted_plan)
    assert_nil standalone.journal_entry
    assert_nil converted.journal_entry
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user,
        customer: @customer,
        issue_date: Date.current,
        invoice_lines_attributes: [
          { service: @service, description: "Consulting", quantity: 2, rate_minor: 15_000 },
          { service: @service, description: "Support", quantity: 1, rate_minor: 5_000 }
        ]
      )
    end

    def posting_signature(plan)
      plan.lines.map do |line|
        [ line.account_id, line.debit_kobo, line.credit_kobo, line.counterparty_type, line.counterparty_id ]
      end
    end
end
