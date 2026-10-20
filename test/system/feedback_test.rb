require "application_system_test_case"

class FeedbackTest < ApplicationSystemTestCase
  setup do
    users(:one).update!(password: "password")
  end

  test "a team member reports a bug from any page without leaving it" do
    filed = nil

    GithubIssue.stub(:configured?, true) do
      GithubIssue.stub(:create, ->(**issue) { filed = issue; "https://github.com/x/y/issues/1" }) do
        visit new_session_path
        fill_in "Email", with: users(:one).email_address
        fill_in "Password", with: "password"
        click_on "Sign in"
        assert_current_path root_path

        visit customers_path
        click_on "Send feedback"
        within("#modal dialog") do
          fill_in "feedback_report[description]", with: "Customer list does not refresh after adding one"
          click_on "Send"
          assert_text "Thanks, we got it"
          click_on "Done"
        end

        assert_no_selector "#modal dialog"
        assert_current_path customers_path
      end
    end

    assert_equal "Bug: Customer list does not refresh after adding one", filed[:title]
    assert_includes filed[:body], "`/customers`"
  end
end
