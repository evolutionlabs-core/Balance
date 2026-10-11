require "test_helper"

class Engine::Rules::RuleFetcherTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Fetcher Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @other_workspace = Workspace.create!(name: "Fetcher Other", currency_code: "NGN")
    @other = Ledger.create!(workspace: @other_workspace, name: "General", currency_code: "NGN")
  end

  test "a rule with no scope funnels down to every command" do
    global = create_rule

    assert_equal [ global ], fetch(ledger_id: @ledger.id)
    assert_equal [ global ], fetch(ledger_id: @other.id, source_type: "Invoice", action: "issue")
  end

  test "each scope axis filters independently" do
    ledger_rule = create_rule(ledger: @ledger)
    source_rule = create_rule(source_type: "Invoice")
    action_rule = create_rule(action: "issue")

    assert_equal [ ledger_rule, source_rule, action_rule ].map(&:id).sort,
      fetch(ledger_id: @ledger.id, source_type: "Invoice", action: "issue").map(&:id).sort

    # Other ledger: only the ledger-scoped rule drops out, the rest are
    # wildcards on ledger.
    assert_equal [ source_rule, action_rule ].map(&:id).sort,
      fetch(ledger_id: @other.id, source_type: "Invoice", action: "issue").map(&:id).sort

    # Other source: only the source-scoped rule drops out.
    assert_equal [ ledger_rule, action_rule ].map(&:id).sort,
      fetch(ledger_id: @ledger.id, source_type: "Receipt", action: "issue").map(&:id).sort

    # Other action: only the action-scoped rule drops out.
    assert_equal [ ledger_rule, source_rule ].map(&:id).sort,
      fetch(ledger_id: @ledger.id, source_type: "Invoice", action: "pay").map(&:id).sort

    # Mismatch on every axis: nothing fires.
    assert_empty fetch(ledger_id: @other.id, source_type: "Receipt", action: "pay")
  end

  test "inactive rules are never fetched" do
    create_rule(active: false)

    assert_empty fetch(ledger_id: @ledger.id)
  end

  test "rules come back in creation order" do
    first = create_rule
    second = create_rule

    assert_equal [ first.id, second.id ], fetch(ledger_id: @ledger.id).map(&:id)
  end

  private
    def create_rule(ledger: nil, source_type: nil, action: nil, active: true)
      Rule.create!(
        name: "rule",
        severity: "warn",
        message: "note",
        active: active,
        ledger: ledger,
        source_type: source_type,
        action: action,
        conditions: []
      )
    end

    def fetch(scope)
      Engine::Rules::RuleFetcher.call(scope)
    end
end
