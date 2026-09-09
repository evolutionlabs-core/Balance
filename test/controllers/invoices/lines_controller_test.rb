require "test_helper"

class Invoices::LinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @invoice = @workspace.invoices.create!(user: users(:one), currency_code: "NGN")
    sign_in_as(users(:one))
    @headers = { Accept: "text/vnd.turbo-stream.html" }
  end

  test "creates a draft line and appends it" do
    assert_difference "@invoice.invoice_lines.count", 1 do
      post invoice_lines_path(@invoice), headers: @headers
    end
    assert_response :success
    assert_select "turbo-stream[action='append'][target='invoice_lines']"
    assert_select "input[name$='[id]'], input[name$='[_destroy]']", count: 0
  end

  test "updates a line and invoice totals together" do
    line = @invoice.add_line
    patch invoice_line_path(@invoice, line), params: { invoice_line: { description: "Consulting", quantity: 2, rate: 150 } }, headers: @headers

    assert_response :success
    assert_equal 30_000, line.reload.amount_minor
    assert_equal 30_000, @invoice.reload.total_minor
    assert_select "turbo-stream[target='invoice_total'] template", text: "NGN 300.00"
  end

  test "invalid edits preserve saved totals and return row errors" do
    line = @invoice.add_line
    @invoice.change_line(line.id, quantity: 2, rate: 150)
    patch invoice_line_path(@invoice, line), params: { invoice_line: { quantity: 0 } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal 2, line.reload.quantity
    assert_equal 30_000, @invoice.reload.total_minor
    assert_select "turbo-stream[target='#{dom_id(line, :errors)}']", text: /Quantity must be greater than 0/
    assert_select "turbo-stream[target='invoice_total']", count: 0
  end

  test "deletes the line and streams its removal and new totals" do
    line = @invoice.add_line
    @invoice.change_line(line.id, quantity: 2, rate: 150)
    assert_difference "InvoiceLine.count", -1 do
      delete invoice_line_path(@invoice, line), headers: @headers
    end
    assert_response :success
    assert_select "turbo-stream[action='remove'][target='#{dom_id(line)}']"
    assert_select "input[name$='[_destroy]']", count: 0
    assert_equal 0, @invoice.reload.total_minor
  end

  test "cannot delete or edit a line belonging to another invoice" do
    other = @workspace.invoices.create!(user: users(:one))
    line = other.add_line
    delete invoice_line_path(@invoice, line), headers: @headers
    assert_response :not_found
    patch invoice_line_path(@invoice, line), params: { invoice_line: { quantity: 2 } }, headers: @headers
    assert_response :not_found
    assert line.reload
  end

  test "cannot change another workspace invoice" do
    other = workspaces(:bola_shop).invoices.create!(user: users(:two))
    post invoice_lines_path(other), headers: @headers
    assert_response :not_found
  end
end
