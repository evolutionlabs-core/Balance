require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.contacts.create!(
      name: "Example Customer",
      contact_kind: "business",
      email: "customer@example.com",
      role_names: %w[customer]
    )
    sign_in_as(@user)
  end

  test "new invoice shows the full form without persisting anything" do
    assert_no_difference [ "Invoice.count", "InvoiceLine.count" ] do
      get new_invoice_path
    end

    assert_response :success
    assert_select "#invoice_line_items"
    assert_select "tr.invoice-line", count: 2
    assert_select "button", text: "Save and preview"
    assert_select "form#new_invoice_form"
    assert_select "nav[aria-label='Invoice views']" do
      assert_select "span", text: "Preview"
      assert_select "a, span", text: "Edit", count: 0
    end
  end

  test "save and preview creates the invoice and redirects to show" do
    assert_difference "Invoice.count", 1 do
      post invoices_path, params: invoice_params
    end
    invoice = @workspace.invoices.order(:id).last
    assert_redirected_to invoice_path(invoice)
  end

  test "invalid creation re-renders the unsaved form" do
    attributes = invoice_params
    attributes[:invoice][:invoice_lines_attributes]["0"][:quantity] = 0
    assert_no_difference "Invoice.count" do
      post invoices_path, params: attributes
    end
    assert_response :unprocessable_content
    assert_select "#new_invoice_form"
    assert_select "input[name='invoice[invoice_lines_attributes][0][description]'][value='Consulting']"
  end

  test "invoice table links to previews and has separate edit actions" do
    invoice = create_invoice
    get invoices_path

    assert_select "th", text: "Actions"
    assert_select "tbody a[href=?]", invoice_path(invoice), count: 5
    assert_select "tbody a[href=?]", edit_invoice_path(invoice), text: "Edit"
  end

  test "creates a workspace-scoped draft with calculated totals" do
    assert_difference("Invoice.count", 1) do
      post invoices_path, params: invoice_params, as: :json
    end

    assert_response :created
    invoice = @workspace.invoices.order(:id).last
    assert_equal @user, invoice.user
    assert_equal @customer, invoice.contact
    assert invoice.draft?
    assert_equal 30_000, invoice.total_minor
    assert_equal 30_000, response.parsed_body["total_minor"]
  end

  test "cannot save an invoice without a customer" do
    assert_no_difference "Invoice.count" do
      post invoices_path, params: { invoice: { currency_code: "NGN" } }, as: :json
    end
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Customer can't be blank"
  end

  test "cannot remove the customer from a saved invoice" do
    invoice = create_invoice
    patch invoice_path(invoice), params: { invoice: { contact_id: "" } }, as: :json
    assert_response :unprocessable_content
    assert_equal @customer, invoice.reload.contact
  end

  test "editing an invoice without lines renders an unsaved empty row" do
    invoice = @workspace.invoices.create!(user: @user, contact: @customer)
    assert_no_difference "InvoiceLine.count" do
      get edit_invoice_path(invoice)
    end
    assert_response :success
    assert_select "tr.invoice-line", count: 1
    assert_select "form[action=?][method='post']", invoice_lines_path(invoice)
    assert_select "p", text: "Changes are saved to this draft.", count: 0
  end

  test "returns preview-ready invoice data" do
    invoice = create_invoice

    get invoice_path(invoice), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "Ada's Store", payload.dig("business", "name")
    assert_equal @customer.name, payload.dig("customer", "name")
    assert_equal "Consulting", payload.dig("lines", 0, "description")
    assert_equal 30_000, payload.dig("lines", 0, "amount_minor")
  end

  test "updates a draft and recalculates totals" do
    invoice = create_invoice
    line = invoice.invoice_lines.first

    patch invoice_path(invoice), params: {
      invoice: {
        contact_id: @customer.id,
        issue_date: invoice.issue_date,
        due_date: invoice.due_date,
        currency_code: invoice.currency_code,
        invoice_lines_attributes: {
          "0" => { id: line.id, description: "Consulting", quantity: 3, rate_minor: 15_000 }
        }
      }
    }, as: :json

    assert_response :success
    assert_equal 45_000, invoice.reload.total_minor
  end

  test "downloads the saved invoice as a PDF attachment" do
    invoice = create_invoice

    get invoice_path(invoice)
    assert_select "a[href=?][data-turbo='false']", invoice_path(invoice, format: :pdf), text: "Download PDF"
    assert_select "a[href=?]", edit_invoice_path(invoice), text: "Edit"

    assert_no_difference [ "Invoice.count", "InvoiceLine.count" ] do
      get invoice_path(invoice, format: :pdf)
    end
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment;.*invoice-#{invoice.id}\.pdf/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
    assert_equal 30_000, invoice.reload.total_minor
  end

  test "rejects invalid invoice data" do
    params = invoice_params
    params[:invoice][:invoice_lines_attributes]["0"][:quantity] = 0

    assert_no_difference("Invoice.count") do
      post invoices_path, params: params, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Invoice lines quantity must be greater than 0"
  end

  test "cannot access another workspace invoice" do
    other_workspace = workspaces(:bola_shop)
    other_user = users(:two)
    other_contact = other_workspace.contacts.create!(
      name: "Other Customer",
      contact_kind: "business",
      email: "other@example.com",
      role_names: %w[customer]
    )
    invoice = other_workspace.invoices.create!(
      user: other_user,
      contact: other_contact,
      issue_date: Date.current,
      due_date: Date.current + 30.days,
      currency_code: "NGN",
      invoice_lines_attributes: [ { description: "Consulting", quantity: 1, rate_minor: 10_000 } ]
    )

    get invoice_path(invoice), as: :json

    assert_response :not_found

    get invoice_path(invoice, format: :pdf)
    assert_response :not_found
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user,
        contact: @customer,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate_minor: 15_000 } ]
      )
    end

    def invoice_params
      {
        invoice: {
          contact_id: @customer.id,
          issue_date: Date.current,
          due_date: Date.current + 30.days,
          currency_code: "NGN",
          invoice_lines_attributes: {
            "0" => { description: "Consulting", quantity: 2, rate_minor: 15_000 }
          }
        }
      }
    end
end
