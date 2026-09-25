require "test_helper"

class EstimateReviewsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @workspace = workspaces(:ada_store)
    @customer = @workspace.customers.create!(name: "Client", customer_type: "business", email: "client@example.com")
    @project = @workspace.projects.create!(name: "Private project", customer: @customer)
    @estimate = @workspace.estimates.create!(user: users(:one), customer: @customer, project: @project,
      notes: "Review these terms", line_items_attributes: [ { description: "Hosting", quantity: 2, rate: 500 } ])
    @estimate.send_to_client!
    @token = @estimate.generate_token_for(:client_review)
  end

  test "anonymous review displays only the estimate and never decides on GET" do
    get estimate_review_path(@token), params: { decision: "accepted" }

    assert_response :success
    assert @estimate.reload.sent?
    assert_nil @estimate.client_decided_at
    assert_select "td", text: "Hosting"
    assert_select "button", text: "Accept estimate"
    assert_select "button", text: "Decline estimate"
    assert_select "form[method='post']", count: 2
    assert_select "a[href=?]", project_path(@project), count: 0
    assert_not_includes response.body, "Private project"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_includes response.headers["X-Robots-Tag"], "noindex"
  end

  test "accept records the reviewed content and consumes the link" do
    reviewed = @estimate.review_content
    post estimate_review_path(@token), params: { decision: "accepted" }

    assert_response :success
    assert @estimate.reload.approved?
    assert_equal "accepted", @estimate.client_decision
    assert_not_nil @estimate.client_decided_at
    assert_equal reviewed, @estimate.client_review_snapshot
    assert_select "h1", text: "Estimate #{@estimate.number} accepted"

    post estimate_review_path(@token), params: { decision: "declined" }
    assert_response :gone
    assert @estimate.reload.approved?
    assert_equal reviewed, @estimate.client_review_snapshot

    @estimate.update!(notes: "Later edit")
    assert_equal "Review these terms", @estimate.reload.client_review_snapshot["notes"]
  end

  test "decline records a decision and reopening does not reactivate an old link" do
    post estimate_review_path(@token), params: { decision: "declined" }
    assert_response :success
    assert @estimate.reload.declined?
    assert_equal "declined", @estimate.client_decision

    @estimate.reopen!
    @estimate.send_to_client!
    get estimate_review_path(@token)
    assert_response :gone
    assert @estimate.reload.sent?
  end

  test "edits invalidate a previously viewed link including equal-value line edits" do
    get estimate_review_path(@token)
    assert_response :success
    @estimate.update!(line_items_attributes: [ { id: @estimate.line_items.first.id, description: "Different service" } ])

    post estimate_review_path(@token), params: { decision: "accepted" }
    assert_response :gone
    assert @estimate.reload.sent?
    assert_nil @estimate.client_decided_at

    get estimate_review_path(@estimate.generate_token_for(:client_review))
    assert_response :success
    assert_select "td", text: "Different service"
  end

  test "changing content back does not revive a previously shared link" do
    line = @estimate.line_items.first
    @estimate.update!(line_items_attributes: [ { id: line.id, description: "Changed" } ])
    @estimate.update!(line_items_attributes: [ { id: line.id, description: "Hosting" } ])

    post estimate_review_path(@token), params: { decision: "accepted" }
    assert_response :gone
    assert @estimate.reload.sent?
  end

  test "public decision forms require a valid CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get estimate_review_path(@token)
    csrf_token = css_select("input[name='authenticity_token']").first["value"]
    post estimate_review_path(@token), params: { decision: "accepted" }
    assert_response :unprocessable_entity
    assert @estimate.reload.sent?

    post estimate_review_path(@token), params: { decision: "accepted", authenticity_token: csrf_token }
    assert_response :success
    assert @estimate.reload.approved?
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "invalid expired and wrong-purpose tokens do not expose the estimate" do
    [ "invalid", @token + "tampered", @estimate.signed_id ].each do |token|
      get estimate_review_path(token)
      assert_response :gone
      assert_not_includes response.body, "Hosting"
    end

    travel 31.days do
      post estimate_review_path(@token), params: { decision: "accepted" }
      assert_response :gone
    end
    assert @estimate.reload.sent?
  end

  test "draft estimates and unsupported decisions cannot be approved" do
    post estimate_review_path(@token), params: { decision: "approved" }
    assert_response :gone
    assert @estimate.reload.sent?

    @estimate.update!(status: "draft")
    post estimate_review_path(@estimate.generate_token_for(:client_review)), params: { decision: "accepted" }
    assert_response :gone
    assert @estimate.reload.draft?
  end

  test "token selects only its estimate regardless of submitted IDs or signed-in workspace" do
    other = @workspace.estimates.create!(user: users(:one), customer: @customer, project: @project)
    other.send_to_client!
    sign_in_as(users(:two))

    post estimate_review_path(@token), params: { decision: "accepted", estimate_id: other.id, workspace_id: workspaces(:bola_shop).id }
    assert_response :success
    assert @estimate.reload.approved?
    assert other.reload.sent?
  end

  test "owner can create and copy a review link and retain manual decisions and PDF" do
    sign_in_as(users(:one))
    @estimate.update!(status: "draft")

    post project_estimate_review_link_path(@estimate)
    assert_redirected_to project_estimate_path(@estimate)
    assert @estimate.reload.sent?
    follow_redirect!
    assert_select "button[aria-label='Client actions']"
    assert_select "button[data-copy-value-value]", text: /Copy client link/
    assert_select "input#client-review-link", count: 0
    assert_select "form[action=?]", project_estimate_approval_path(@estimate)
    assert_select "form[action=?]", project_estimate_decline_path(@estimate)
    assert_select "a[href=?]", project_estimate_path(@estimate, format: :pdf)

    token = @estimate.generate_token_for(:client_review)
    post project_estimate_approval_path(@estimate)
    assert @estimate.reload.approved?
    assert_nil @estimate.client_decided_at
    get estimate_review_path(token)
    assert_response :gone
  end

  test "owner cannot share an estimate that has already received a decision" do
    sign_in_as(users(:one))
    @estimate.approve!

    post project_estimate_review_link_path(@estimate)
    assert_redirected_to project_estimate_path(@estimate)
    assert_equal "Only draft or sent estimates can be shared.", flash[:alert]
    assert @estimate.reload.approved?
  end

  test "preserves the original client review after later edits" do
    post estimate_review_path(@token), params: { decision: "accepted" }
    @estimate.reload.update!(notes: "Updated terms")

    assert_equal "Review these terms", @estimate.client_review_snapshot.fetch("notes")
    assert_equal "Updated terms", @estimate.notes
  end

  test "creating links requires authentication and workspace ownership" do
    post project_estimate_review_link_path(@estimate)
    assert_redirected_to new_session_path

    sign_in_as(users(:two))
    post project_estimate_review_link_path(@estimate)
    assert_response :not_found
    assert @estimate.reload.sent?
  end
end
