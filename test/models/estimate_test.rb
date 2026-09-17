require "test_helper"

class EstimateTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @other_workspace = workspaces(:bola_shop)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Estimate Customer", customer_type: "business", email: "estimate@example.com", address: "12 Allen Ave")
    @project = @workspace.projects.create!(customer: @customer, name: "Estimate Villa")
  end

  test "prefills billing address from customer and totals lines in kobo" do
    estimate = @workspace.estimates.build(
      user: @user, customer: @customer, project: @project,
      line_items_attributes: {
        "0" => { description: "Hosting", quantity: "12", rate: "5000" },
        "1" => { description: "Domain", quantity: "1", rate: "15000" }
      }
    )

    assert estimate.valid?, estimate.errors.full_messages.to_sentence
    assert_equal "12 Allen Ave", estimate.bill_to_address
    assert_equal 12 * 500_000 + 1_500_000, estimate.total_minor
    assert_equal "draft", estimate.status
  end

  test "rejects customer from another workspace" do
    other_customer = @other_workspace.customers.create!(name: "Other", customer_type: "single", email: "other@example.com")
    estimate = @workspace.estimates.build(user: @user, customer: other_customer, project: @project)

    assert_not estimate.valid?
    assert_includes estimate.errors[:customer], "must belong to the workspace"
  end

  test "rejects project of another customer" do
    other_customer = @workspace.customers.create!(name: "Other", customer_type: "single", email: "other2@example.com")
    estimate = @workspace.estimates.build(user: @user, customer: other_customer, project: @project)

    assert_not estimate.valid?
    assert_includes estimate.errors[:project], "must belong to the same customer as the estimate"
  end

  test "lifecycle moves draft to sent to approved or declined and back to draft" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert estimate.send_to_client!
    assert estimate.sent?
    assert estimate.approve!
    assert estimate.approved?

    declined = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    declined.send_to_client!
    assert declined.decline!
    assert declined.declined?
    assert declined.reopen!
    assert declined.draft?
  end

  test "rejects transitions outside the lifecycle" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert_not estimate.approve!
    assert_not estimate.decline!
    assert_not estimate.reopen!
    assert estimate.draft?
  end

  test "allows edits after sending" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    estimate.send_to_client!

    assert estimate.update(notes: "changed")
    assert_equal "changed", estimate.reload.notes
  end

  test "omitted saved rows are removed on update" do
    estimate = @workspace.estimates.create!(
      user: @user, customer: @customer, project: @project,
      line_items_attributes: {
        "0" => { description: "Hosting", quantity: "12", rate: "5000" },
        "1" => { description: "Domain", quantity: "1", rate: "15000" }
      }
    )
    kept = estimate.line_items.find_by(description: "Hosting")

    assert_difference("EstimateLineItem.count", -1) do
      estimate.update!(line_items_attributes: { "-#{kept.id}" => { description: "Hosting", quantity: "12", rate: "5000" } })
    end

    assert_equal [ "Hosting" ], estimate.reload.line_items.pluck(:description)
  end

  test "number derives from id" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert_equal format("EST-%06d", estimate.id), estimate.number
  end
end
