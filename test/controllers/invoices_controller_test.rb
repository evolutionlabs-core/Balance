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

  test "creates an incomplete draft" do
    assert_difference("Invoice.count", 1) do
      post invoices_path, params: { invoice: { currency_code: "NGN" } }, as: :json
    end

    assert_response :created
    invoice = @workspace.invoices.order(:id).last
    assert_nil invoice.contact
    assert_nil invoice.invoice_number
    assert_empty invoice.invoice_lines
    assert_equal 0, invoice.total_minor
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
        invoice_number: invoice.invoice_number,
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
      invoice_number: "INV-OTHER",
      issue_date: Date.current,
      due_date: Date.current + 30.days,
      currency_code: "NGN",
      invoice_lines_attributes: [ { description: "Consulting", quantity: 1, rate_minor: 10_000 } ]
    )

    get invoice_path(invoice), as: :json

    assert_response :not_found
  end

  private
    def create_invoice
      @workspace.invoices.create!(
        user: @user,
        contact: @customer,
        invoice_number: "INV-001",
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
          invoice_number: "INV-001",
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
