require "test_helper"

class Invoice::PdfTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.contacts.create!(name: "Original Customer", contact_kind: "business",
      email: "original-customer@example.com", address: "1 Customer Road", role_names: %w[customer])
  end

  test "renders saved party snapshots rather than current records" do
    invoice = create_invoice
    @workspace.update!(name: "Changed Business")
    @customer.update!(name: "Changed Customer")

    text = pdf_text(Invoice::Pdf.new(invoice.reload).render)

    assert_includes text, "Ada's Store"
    assert_includes text, "Original Customer"
    assert_not_includes text, "Changed Business"
    assert_not_includes text, "Changed Customer"
  end

  test "renders missing optional details and totals" do
    invoice = create_invoice
    invoice.update_columns(business_address: nil, bill_to_email: nil, bill_to_address: nil)

    text = pdf_text(Invoice::Pdf.new(invoice.reload).render)

    assert_includes text, "INVOICE"
    assert_includes text, "NGN 150.00"
  end

  test "matches show-page fallbacks without changing the invoice" do
    invoice = create_invoice
    invoice.update_columns(business_name: nil, business_email: nil, business_address: nil,
      bill_to_name: nil, bill_to_email: nil, bill_to_address: nil)

    text = pdf_text(Invoice::Pdf.new(invoice.reload).render)

    assert_includes text, "Ada's Store"
    assert_includes text, "Original Customer"
    assert_nil invoice.reload.business_name
    assert_nil invoice.bill_to_name
  end

  test "paginates long invoices" do
    invoice = create_invoice(lines: Array.new(80) { |index| line("Service #{index + 1}") })

    pdf = Invoice::Pdf.new(invoice).render

    assert_operator pdf.scan(%r{/Type /Page\b}).size, :>, 1
  end

  private
    def create_invoice(lines: [ line("Consulting") ])
      @workspace.invoices.create!(user: @user, contact: @customer, issue_date: Date.new(2026, 9, 10),
        due_date: Date.new(2026, 10, 10), currency_code: "NGN", invoice_lines_attributes: lines)
    end

    def line(description)
      { description: description, quantity: 1, rate_minor: 15_000 }
    end

    def pdf_text(pdf)
      pdf.scan(/<([0-9a-f]+)>/i).flatten.map { |hex| [ hex ].pack("H*") }.join(" ")
    end
end
