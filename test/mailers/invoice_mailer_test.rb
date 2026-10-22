require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  setup do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    service = workspace.services.create!(name: "Consulting", income_account: ledger.accounts.find_by!(name: "Other Income"))
    customer = workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = workspace.invoices.create!(
      user: users(:one), customer: customer, issue_date: Date.current, due_date: Date.current + 14,
      invoice_lines_attributes: [ { service_id: service.id, description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
  end

  test "emails the invoice with its balance, message, secure link and PDF" do
    mail = InvoiceMailer.with(invoice: @invoice, to: "acme@example.com", subject: "Invoice due", message: "Thanks for the work.").issued
    html = mail.html_part.body.to_s

    assert_equal [ "acme@example.com" ], mail.to
    assert_equal "Invoice due", mail.subject
    assert_equal [ users(:one).email_address ], mail.reply_to
    assert_includes html, "NGN 300.00"
    assert_includes html, "Thanks for the work."
    assert_match %r{http://example.com/client/invoices/[^"]+}, html
    assert_equal [ "invoice-#{@invoice.invoice_number}.pdf" ], mail.attachments.map(&:filename)
    assert_includes mail.text_part.body.to_s, "Thanks for the work."
  end
end
