require "application_system_test_case"

class EstimateReviewTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(password: "password")
    workspace = workspaces(:ada_store)
    customer = workspace.customers.create!(name: "Review Client", customer_type: "business", email: "review@example.com")
    project = workspace.projects.create!(name: "Review Project", customer: customer)
    @estimate = workspace.estimates.create!(user: @user, customer: customer, project: project,
      line_items_attributes: [ { description: "Hosting", quantity: 2, rate: 500 } ])
  end

  test "owner shares a link and an anonymous client accepts the displayed estimate" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path

    visit project_estimate_path(@estimate)
    click_on "Create client review link"
    assert_selector "input#client-review-link"
    link = find("#client-review-link").value
    click_on "Copy link"
    assert_selector "[role='status']", text: /Link copied|Select and copy/

    Capybara.reset_sessions!
    visit link
    assert_selector "h1", text: "Review estimate #{@estimate.number}"
    assert_selector "td", text: "Hosting"
    assert_selector "dd", text: "NGN 1,000.00"
    assert @estimate.reload.sent?
    click_on "Accept estimate"
    assert_selector "h1", text: "Estimate #{@estimate.number} accepted"
    assert @estimate.reload.approved?
    assert_equal "Hosting", @estimate.client_review_snapshot["line_items"].first["description"]

    visit link
    assert_selector "h1", text: "This review link is no longer available"
  end

  test "anonymous client declines on a small screen" do
    @estimate.send_to_client!
    page.current_window.resize_to(390, 844)
    visit estimate_review_path(@estimate.generate_token_for(:client_review))
    assert_selector "td", text: "Hosting"
    click_on "Decline estimate"
    assert_selector "h1", text: "Estimate #{@estimate.number} declined"
    assert @estimate.reload.declined?
  end
end
