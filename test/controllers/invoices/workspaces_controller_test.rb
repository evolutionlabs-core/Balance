require "test_helper"

class Invoices::WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    contact = @workspace.contacts.create!(name: "Customer", contact_kind: "business", email: "customer@example.com", role_names: %w[customer])
    @invoice = @workspace.invoices.create!(user: @user, contact: contact)
    sign_in_as(@user)
  end

  test "updates workspace and refreshes saved invoice business fields" do
    patch invoice_workspace_path(invoice_id: @invoice.id), params: {
      workspace: { name: "Ada Ventures", address: "14 Marina Road" }
    }, headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action='replace'][target='#{dom_id(@invoice, :business)}']"
    assert_equal "Ada Ventures", @invoice.reload.business_name
    assert_equal "14 Marina Road", @invoice.business_address
  end
end
