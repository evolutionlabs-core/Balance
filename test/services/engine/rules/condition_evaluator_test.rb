require "test_helper"

class Engine::Rules::ConditionEvaluatorTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Conditions Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit")
  end

  test "an empty condition list matches unconditionally" do
    assert matches?([], command)
  end

  test "equality on command fields" do
    assert matches?([ { "field" => "action", "op" => "eq", "value" => "issue" } ], command(action: "issue"))
    refute matches?([ { "field" => "action", "op" => "eq", "value" => "issue" } ], command)
    assert matches?([ { "field" => "action", "op" => "ne", "value" => "issue" } ], command)
  end

  test "numeric comparisons on totals" do
    big = command(amount: 2_000_000)
    small = command(amount: 1000)

    assert matches?([ { "field" => "total_debits", "op" => "gte", "value" => 1_000_000 } ], big)
    refute matches?([ { "field" => "total_debits", "op" => "gte", "value" => 1_000_000 } ], small)
    assert matches?([ { "field" => "total_credits", "op" => "lt", "value" => 2000 } ], small)
    assert matches?([ { "field" => "total_debits", "op" => "gt", "value" => 999 } ], small)
    assert matches?([ { "field" => "total_debits", "op" => "lte", "value" => 1000 } ], small)
  end

  test "membership checks" do
    rule_conditions = [ { "field" => "action", "op" => "in", "value" => %w[issue reverse] } ]

    assert matches?(rule_conditions, command(action: "issue"))
    refute matches?(rule_conditions, command(action: "pay"))
  end

  test "nil value checks for absence and presence" do
    assert matches?([ { "field" => "source_type", "op" => "eq", "value" => nil } ], command)
    refute matches?([ { "field" => "source_type", "op" => "ne", "value" => nil } ], command)
    assert matches?(
      [ { "field" => "source_type", "op" => "ne", "value" => nil } ],
      command(source_type: "Invoice")
    )
  end

  test "metadata paths resolve dotted keys" do
    with_facts = command(metadata: { channel: "vip", tier: { level: 3 } })

    assert matches?([ { "field" => "metadata.channel", "op" => "eq", "value" => "vip" } ], with_facts)
    assert matches?([ { "field" => "metadata.tier.level", "op" => "eq", "value" => 3 } ], with_facts)
    refute matches?([ { "field" => "metadata.channel", "op" => "eq", "value" => "vip" } ], command)
  end

  test "every condition must hold" do
    conditions = [
      { "field" => "total_debits", "op" => "gte", "value" => 500 },
      { "field" => "action", "op" => "eq", "value" => "issue" }
    ]

    refute matches?(conditions, command(amount: 1000))
    assert matches?(conditions, command(amount: 1000, action: "issue"))
  end

  test "an unknown top-level field raises" do
    assert_raises(ArgumentError) do
      matches?([ { "field" => "customer_type", "op" => "eq", "value" => "vip" } ], command)
    end
  end

  test "an unknown operator raises" do
    assert_raises(ArgumentError) do
      matches?([ { "field" => "action", "op" => "matches", "value" => "issue" } ], command)
    end
  end

  test "a malformed condition raises" do
    assert_raises(ArgumentError) do
      matches?([ "action == issue" ], command)
    end
  end

  private
    def matches?(conditions, command)
      Engine::Rules::ConditionEvaluator.matches?(Rule.new(conditions: conditions), command)
    end

    def command(amount: 1000, source_type: nil, action: nil, metadata: {})
      Engine::Command.new(
        ledger: @ledger,
        effective_date: Date.current,
        source_type: source_type,
        action: action,
        metadata: metadata,
        lines: [
          Engine::Command::Line.new(ledger_account: @cash, debit: amount, credit: 0),
          Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: amount)
        ]
      )
    end
end
