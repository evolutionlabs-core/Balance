require "test_helper"

class Engine::RulesTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Rules Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit")
  end

  test "allows when no rules exist" do
    receipt = post

    assert receipt.success?
    assert_equal :allow, receipt.verdict
    assert_empty receipt.warnings
  end

  test "a BLOCK rule raises a typed error and writes nothing" do
    rule = create_rule(severity: "block", message: "blocked by policy")

    error = assert_raises(Engine::Errors::BusinessRuleError) { post }
    assert_equal "blocked by policy", error.message
    assert_equal rule.id, error.rule.id
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "a BLOCK rule carries warnings collected before it" do
    create_rule(severity: "warn", message: "first warning")
    create_rule(severity: "block", message: "blocked")

    error = assert_raises(Engine::Errors::BusinessRuleError) { post }
    assert_equal [ "first warning" ], error.warnings
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rules after a BLOCK never run" do
    create_rule(severity: "block", message: "blocked")
    create_rule(severity: "warn", message: "never seen")

    error = assert_raises(Engine::Errors::BusinessRuleError) { post }
    assert_empty error.warnings
  end

  test "REQUIRE_APPROVAL pauses without writing" do
    create_rule(severity: "require_approval", message: "needs a human")

    receipt = post

    refute receipt.success?
    assert_equal :pause, receipt.verdict
    assert_nil receipt.entry
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "WARN appends to the receipt and the entry still posts" do
    create_rule(severity: "warn", message: "unusual channel")

    receipt = post

    assert receipt.success?
    assert_equal [ "unusual channel" ], receipt.warnings
    assert_equal 1, @ledger.ledger_entries.count
  end

  test "out-of-scope rules do not fire" do
    create_rule(severity: "block", message: "invoices only", source_type: "Invoice")

    assert post.success?
    assert_raises(Engine::Errors::BusinessRuleError) { post(source_type: "Invoice", action: "issue") }
  end

  test "conditions filter which commands a rule fires on" do
    create_rule(
      severity: "block",
      message: "too large",
      conditions: [ { "field" => "total_debits", "op" => "gte", "value" => 1_000_000 } ]
    )

    assert post(amount: 1000).success?
    assert_raises(Engine::Errors::BusinessRuleError) { post(amount: 2_000_000) }
  end

  test "conditions read business facts from command metadata" do
    create_rule(
      severity: "warn",
      message: "vip channel",
      conditions: [ { "field" => "metadata.channel", "op" => "eq", "value" => "vip" } ]
    )

    assert_empty post.warnings
    assert_equal [ "vip channel" ], post(metadata: { channel: "vip" }).warnings
  end

  test "inactive rules never fire" do
    create_rule(severity: "block", message: "blocked", active: false)

    assert post.success?
  end

  private
    def create_rule(severity:, message:, active: true, source_type: nil, action: nil, conditions: [])
      Rule.create!(
        name: "#{severity} rule",
        severity: severity,
        message: message,
        active: active,
        source_type: source_type,
        action: action,
        conditions: conditions
      )
    end

    def post(amount: 1000, source_type: nil, action: nil, metadata: {})
      Engine::PostingOrchestrator.call(
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
      )
    end
end
