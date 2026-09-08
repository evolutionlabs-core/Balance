require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.contacts.create!(
      name: "Example Customer",
      contact_kind: "business",
      email: "customer@example.com",
      role_names: %w[customer]
    )
  end

  test "calculates line amounts and invoice totals in minor units" do
    invoice = build_invoice(lines: [
      { description: "Consulting", quantity: 2, rate_minor: 15_000 },
      { description: "Support", quantity: 1.5, rate_minor: 10_000 }
    ])

    assert invoice.valid?, invoice.errors.full_messages.to_sentence
    assert_equal [ 30_000, 15_000 ], invoice.invoice_lines.map(&:amount_minor)
    assert_equal [ 0, 1 ], invoice.invoice_lines.map(&:position)
    assert_equal 45_000, invoice.subtotal_minor
    assert_equal 45_000, invoice.total_minor
  end

  test "recalculates client supplied totals and line amounts" do
    invoice = build_invoice(lines: [
      { description: "Consulting", quantity: 2, rate_minor: 15_000, amount_minor: 1 }
    ])
    invoice.subtotal_minor = 1
    invoice.total_minor = 1

    invoice.save!

    assert_equal 30_000, invoice.invoice_lines.first.amount_minor
    assert_equal 30_000, invoice.subtotal_minor
    assert_equal 30_000, invoice.total_minor
  end

  test "allows a draft without lines" do
    invoice = build_invoice(lines: [])

    assert invoice.valid?
    assert_equal 0, invoice.subtotal_minor
    assert_equal 0, invoice.total_minor
  end

  test "allows an incomplete draft" do
    invoice = build_invoice(contact: nil, lines: [ { description: "Draft line", quantity: nil, rate_minor: nil } ])
    invoice.invoice_number = nil
    invoice.issue_date = nil
    invoice.due_date = nil

    assert invoice.valid?, invoice.errors.full_messages.to_sentence
    assert_equal 0, invoice.invoice_lines.first.amount_minor
  end

  test "requires a unique invoice number within the workspace" do
    build_invoice.save!
    duplicate = build_invoice

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:invoice_number], "has already been taken"
  end

  private
    def build_invoice(contact: @customer, user: @user, lines: nil)
      lines ||= [ { description: "Consulting", quantity: 2, rate_minor: 15_000 } ]

      @workspace.invoices.build(
        user: user,
        contact: contact,
        invoice_number: "INV-001",
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: lines
      )
    end
end
