require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
  end

  test "saves the invoice defaults" do
    patch workspace_path, params: { workspace: {
      name: @workspace.name, default_payment_terms: "net_60", payment_instructions: "GTBank 0123456789", default_invoice_note: "Thanks"
    } }

    assert_redirected_to overview_path
    @workspace.reload
    assert_equal [ "net_60", "GTBank 0123456789", "Thanks" ], [ @workspace.default_payment_terms, @workspace.payment_instructions, @workspace.default_invoice_note ]
  end

  test "rejects custom as a default term" do
    patch workspace_path, params: { workspace: { name: @workspace.name, default_payment_terms: "custom" } }

    assert_response :unprocessable_content
    assert_equal "net_30", @workspace.reload.default_payment_terms
  end
end
