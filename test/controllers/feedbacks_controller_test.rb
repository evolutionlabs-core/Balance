require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "the form is hidden until a GitHub token is configured" do
    GithubIssue.stub(:configured?, false) do
      get overview_path
      assert_select "a[href='#{new_feedback_path}']", count: 0

      get new_feedback_path
      assert_response :not_found
    end
  end

  test "the sidebar links to the feedback form" do
    GithubIssue.stub(:configured?, true) do
      get overview_path
      assert_select "a[href='#{new_feedback_path}'][data-turbo-frame=modal]", text: /Send feedback/

      get new_feedback_path, headers: { "Referer" => "http://www.example.com/invoices/7?tab=email" }
      assert_select "input[name='feedback_report[page]'][value='http://www.example.com/invoices/7?tab=email']"
      assert_select "input[type=radio][name='feedback_report[kind]'][value=bug][checked]"
    end
  end

  test "files a bug as a GitHub issue without personal details" do
    filed = nil
    GithubIssue.stub(:configured?, true) do
      GithubIssue.stub(:create, ->(**issue) { filed = issue; "https://github.com/x/y/issues/1" }) do
        post feedback_path, params: { feedback_report: {
          kind: "bug", description: "The send button does nothing\nI clicked it twice.", page: "http://www.example.com/invoices/7?tab=email"
        } }, headers: { "User-Agent" => "TestBrowser/1.0" }
      end
    end

    assert_response :success
    assert_select "h2", text: "Thanks, we got it"
    assert_equal "Bug: The send button does nothing", filed[:title]
    assert_equal [ "bug" ], filed[:labels]
    assert_includes filed[:body], "I clicked it twice."
    assert_includes filed[:body], "`/invoices/7`"
    assert_includes filed[:body], "TestBrowser/1.0"
    assert_not_includes filed[:body], users(:one).email_address
    assert_not_includes filed[:body], users(:one).full_name.split.last
  end

  test "files an idea as an enhancement" do
    filed = nil
    GithubIssue.stub(:configured?, true) do
      GithubIssue.stub(:create, ->(**issue) { filed = issue; "url" }) do
        post feedback_path, params: { feedback_report: { kind: "idea", description: "Let me export reports to Excel" } }
      end
    end

    assert_equal "Idea: Let me export reports to Excel", filed[:title]
    assert_equal [ "enhancement" ], filed[:labels]
  end

  test "asks for a description before sending" do
    GithubIssue.stub(:configured?, true) do
      GithubIssue.stub(:create, ->(**) { flunk "should not file an empty report" }) do
        post feedback_path, params: { feedback_report: { kind: "bug", description: "  " } }
      end
    end

    assert_response :unprocessable_content
    assert_select "li", text: /Tell us what happened/
  end

  test "keeps the report and explains when GitHub can't be reached" do
    GithubIssue.stub(:configured?, true) do
      GithubIssue.stub(:create, ->(**) { raise GithubIssue::Error, "timeout" }) do
        post feedback_path, params: { feedback_report: { kind: "bug", description: "Totals look wrong" } }
      end
    end

    assert_response :unprocessable_content
    assert_select "li", text: /couldn't send that just now/
    assert_select "textarea", text: "Totals look wrong"
  end
end
