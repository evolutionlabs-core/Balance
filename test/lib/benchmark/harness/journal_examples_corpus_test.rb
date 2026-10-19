require "test_helper"

class Llm::Harness::JournalExamplesCorpusTest < ActiveSupport::TestCase
  test "maps every corpus expectation onto a real row in the workspace chart" do
    cases = Llm::Harness::JournalExamplesCorpus.load!

    assert_predicate cases, :any?
    assert cases.all? { |test_case| test_case.dig("setup", "account_specs").present? }

    cases.each do |test_case|
      chart = chart_for(test_case.fetch("workspace_type"))

      test_case.dig("setup", "account_specs").each do |spec|
        row = chart.find { |account| account["name"] == spec["name"] }
        assert row, "#{test_case.fetch('id')} maps to an unknown chart account: #{spec.fetch('name')}"
        assert_equal spec["base_type"], row["base_type"], test_case.fetch("id")
        assert_equal spec["subtype"], row["subtype"], test_case.fetch("id")
      end
    end
  end

  private
    def chart_for(workspace_type)
      ChartCatalog.accounts_for(workspace_type).map(&:with_indifferent_access)
    end
end
