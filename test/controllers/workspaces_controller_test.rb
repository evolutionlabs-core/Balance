require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @customer = @workspace.contacts.create!(name: "Customer", email: "customer@example.com", contact_kind: "business", role_names: %w[customer])
    sign_in_as(users(:one))
  end

  test "updates invoice business fields with a turbo stream" do
    invoice = @workspace.invoices.create!(contact: @customer, user: users(:one))
    patch workspace_path(invoice_id: invoice.id), params: {
      workspace: { name: "Ada Ventures", address: "14 Marina Road" }
    }, headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='#{dom_id(invoice, :business)}']"
    assert_equal "14 Marina Road", @workspace.reload.address
    assert_equal "14 Marina Road", invoice.reload.business_address
    assert_select "input[name=\"invoice[business_name]\"]", count: 0
  end
end
