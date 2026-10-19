require "test_helper"

class AccountingEngine::PostingTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Engine Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = Account.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")
    @income = Account.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit", code: "4010", subtype: "operating")
  end

  test "posts a balanced command and returns a success receipt" do
    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 1000))

    assert receipt.success?
    assert_equal @ledger, receipt.entry.ledger

    lines = receipt.entry.journal_entry_lines.to_a
    assert_equal [ @cash, @income ], lines.map(&:account)
    assert_equal [ 1000, 0 ], lines.map { |line| line.debit.to_i }
    assert_equal [ 0, 1000 ], lines.map { |line| line.credit.to_i }
    assert_equal 1, @ledger.journal_entries.count
  end

  test "records the source effect on the entry" do
    receipt = AccountingEngine::Posting.call(
      command(debit: 500, credit: 500, source_type: "Invoice", source_id: 7, action: "issue")
    )

    assert receipt.success?
    assert_equal [ "Invoice", 7, "issue" ],
      receipt.entry.values_at(:source_type, :source_id, :action)
  end

  test "rejects an entry dated inside the closed window" do
    close_ledger_through(7.days.ago.to_date)
    closed = AccountingEngine::Command.new(
      ledger: @ledger,
      effective_date: 14.days.ago.to_date,
      lines: [
        AccountingEngine::Command::Line.new(account: @cash, debit: 1000, credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(closed)

    refute receipt.success?
    refute receipt.success?
    assert_includes receipt.errors.join, "closed through"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "allows a posting dated after the closed window" do
    close_ledger_through(7.days.ago.to_date)

    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 1000))

    assert receipt.success?
    assert_equal 1, @ledger.journal_entries.count
  end

  test "rejects a line on an inactive account" do
    @cash.update!(active: false, created_by: "admin")

    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 1000))

    refute receipt.success?
    assert_includes receipt.errors.join, "inactive"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects an unbalanced command and writes nothing" do
    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 900))

    refute receipt.success?
    refute receipt.success?
    assert_nil receipt.entry
    assert_includes receipt.errors.join, "must equal total credits"
    assert_equal 0, @ledger.journal_entries.count
    assert_equal 0, JournalEntryLine.count
  end

  test "rejects a single-line command" do
    command = AccountingEngine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [ AccountingEngine::Command::Line.new(account: @cash, debit: 1000, credit: 0) ]
    )

    receipt = AccountingEngine::Posting.call(command)

    refute receipt.success?
    assert_includes receipt.errors.join, "at least two lines"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "collects every error instead of stopping at the first" do
    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 0))

    refute receipt.success?
    assert_operator receipt.errors.size, :>=, 2
  end

  test "rejects an entry on an inactive ledger" do
    @ledger.update!(status: "closed")

    receipt = AccountingEngine::Posting.call(command(debit: 1000, credit: 1000))

    refute receipt.success?
    assert_includes receipt.errors.join, "closed"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects a line whose account belongs to another ledger" do
    other_workspace = Workspace.create!(name: "Other Workspace", currency_code: "NGN")
    other = Ledger.create!(workspace: other_workspace, name: "General", currency_code: "NGN")
    foreign = Account.create!(ledger: other, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")

    command = AccountingEngine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        AccountingEngine::Command::Line.new(account: foreign, debit: 1000, credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(command)

    refute receipt.success?
    assert_includes receipt.errors.join, "another ledger"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects a command with no ledger" do
    bad = AccountingEngine::Command.new(
      ledger: nil,
      effective_date: Date.current,
      lines: [
        AccountingEngine::Command::Line.new(account: @cash, debit: 1000, credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "missing ledger"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects a non-numeric amount instead of misparsing it" do
    bad = AccountingEngine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        AccountingEngine::Command::Line.new(account: @cash, debit: "lots", credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "must be whole kobo"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects an account that was never persisted" do
    ghost = Account.new(ledger: @ledger, name: "Ghost", base_type: "asset", normal_balance: "debit")
    bad = AccountingEngine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        AccountingEngine::Command::Line.new(account: ghost, debit: 1000, credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "not persisted"
    assert_equal 0, @ledger.journal_entries.count
  end

  test "rejects a ledger that was never persisted" do
    draft = Ledger.new(workspace: @workspace, name: "Draft", currency_code: "NGN")
    bad = AccountingEngine::Command.new(
      ledger: draft,
      effective_date: Date.current,
      lines: [
        AccountingEngine::Command::Line.new(account: @cash, debit: 1000, credit: 0),
        AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = AccountingEngine::Posting.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "not persisted"
  end

  test "numbers entries sequentially within the ledger" do
    first = AccountingEngine::Posting.call(command(debit: 100, credit: 100)).entry
    second = AccountingEngine::Posting.call(command(debit: 200, credit: 200)).entry

    assert_equal [ 1, 2 ], [ first.number, second.number ]
  end

  test "records the user posting the entry" do
    user = users(:one)
    entry = AccountingEngine::Posting.call(command(debit: 100, credit: 100).with(posted_by: user)).entry

    assert_equal user, entry.posted_by
  end

  test "rejects fractional kobo" do
    receipt = AccountingEngine::Posting.call(command(debit: 100.5, credit: 100.5))

    refute receipt.success?
    assert_includes receipt.errors.join, "must be whole kobo"
  end

  test "posts the mirror of an entry and links it as the reversal" do
    original = AccountingEngine::Posting.call(command(debit: 700, credit: 700)).entry

    receipt = AccountingEngine::Posting.call(reversal_of(original))

    assert receipt.success?
    assert_equal original, receipt.entry.reverses_entry
    assert original.reload.reversed?
    assert_equal [ [ @cash, 0, 700 ], [ @income, 700, 0 ] ],
      receipt.entry.journal_entry_lines.map { |line| [ line.account, line.debit, line.credit ] }
  end

  test "rejects a reversal that does not mirror the original" do
    original = AccountingEngine::Posting.call(command(debit: 700, credit: 700)).entry

    receipt = AccountingEngine::Posting.call(reversal_of(original, amount: 500))

    refute receipt.success?
    assert_includes receipt.errors.join, "must mirror every line of entry #1"
    assert_not original.reload.reversed?
  end

  test "rejects reversing an entry twice or reversing a reversal" do
    original = AccountingEngine::Posting.call(command(debit: 700, credit: 700)).entry
    reversal = AccountingEngine::Posting.call(reversal_of(original)).entry

    again = AccountingEngine::Posting.call(reversal_of(original))
    assert_includes again.errors.join, "Entry #1 has already been reversed"

    undo = AccountingEngine::Posting.call(reversal_of(reversal))
    assert_includes undo.errors.join, "Entry #2 is itself a reversal"
  end

  test "rejects a control-account line that names no counterparty" do
    receivable = control_account(@ledger, "accounts_receivable")

    receipt = AccountingEngine::Posting.call(two_lines(receivable, @income))

    refute receipt.success?
    assert_includes receipt.errors.join, "Accounts Receivable is a control account; record it through invoices and invoice payments"
  end

  test "posts a control-account line that names a customer in the workspace" do
    receivable = control_account(@ledger, "accounts_receivable")
    customer = @workspace.customers.create!(name: "Tolu", customer_type: "single", email: "tolu@example.com")

    receipt = AccountingEngine::Posting.call(two_lines(receivable, @income, customer: customer))

    assert receipt.success?
    assert_equal customer, receipt.entry.journal_entry_lines.find_by!(account: receivable).customer
  end

  test "rejects a customer from another workspace" do
    receivable = control_account(@ledger, "accounts_receivable")
    stranger = workspaces(:bola_shop).customers.create!(name: "Stranger", customer_type: "single", email: "stranger@example.com")

    receipt = AccountingEngine::Posting.call(two_lines(receivable, @income, customer: stranger))

    refute receipt.success?
    assert_includes receipt.errors.join, "the customer belongs to another workspace"
  end

  test "rejects a counterparty on an account that is not its control account" do
    customer = @workspace.customers.create!(name: "Ife", customer_type: "single", email: "ife@example.com")

    receipt = AccountingEngine::Posting.call(two_lines(@cash, @income, customer: customer))

    refute receipt.success?
    assert_includes receipt.errors.join, "a customer can only be named on a receivables account"
  end

  test "posting the same source twice returns the first entry as a replay" do
    first = AccountingEngine::Posting.call(command(debit: 900, credit: 900, source_type: "Invoice", source_id: 3, action: "issue"))
    again = AccountingEngine::Posting.call(command(debit: 900, credit: 900, source_type: "Invoice", source_id: 3, action: "issue"))

    assert again.success?
    assert again.replayed?
    assert_equal first.entry, again.entry
    assert_equal 1, @ledger.journal_entries.count
  end

  test "posting the same source with different lines is rejected by name" do
    AccountingEngine::Posting.call(command(debit: 900, credit: 900, source_type: "Invoice", source_id: 3, action: "issue"))
    changed = AccountingEngine::Posting.call(command(debit: 500, credit: 500, source_type: "Invoice", source_id: 3, action: "issue"))

    refute changed.success?
    assert_equal :duplicate_source, changed.errors.sole.code
    assert_equal "This invoice issue is already recorded as entry #1 with different lines", changed.errors.sole.message
  end

  test "every rejection is an AccountingEngine::Error" do
    receipt = AccountingEngine::Posting.call(command(debit: 100, credit: 90))

    assert receipt.errors.all? { |error| error.is_a?(AccountingEngine::Error) }
    assert_equal [ :match ], receipt.errors.map(&:code)
  end

  private
    def control_account(ledger, subtype)
      Account.create!(ledger: ledger, name: subtype.titleize, base_type: "asset", code: "1100", subtype: subtype)
    end

    def two_lines(debit_account, credit_account, customer: nil)
      AccountingEngine::Command.new(
        ledger: @ledger,
        effective_date: Date.current,
        lines: [
          AccountingEngine::Command::Line.new(account: debit_account, debit: 500, credit: 0, customer: customer),
          AccountingEngine::Command::Line.new(account: credit_account, debit: 0, credit: 500)
        ]
      )
    end

    def reversal_of(entry, amount: nil)
      AccountingEngine::Command.new(
        ledger: @ledger,
        effective_date: Date.current,
        reverses_entry: entry,
        lines: entry.journal_entry_lines.map do |line|
          AccountingEngine::Command::Line.new(
            account: line.account,
            debit: line.credit.positive? ? (amount || line.credit) : 0,
            credit: line.debit.positive? ? (amount || line.debit) : 0
          )
        end
      )
    end

    def close_ledger_through(date)
      actor = User.create!(full_name: "Close Owner", email_address: "closeowner@example.com", password: "supersecret123")
      @workspace.memberships.create!(user: actor, role: :owner)
      @ledger.close_books!(through: date, actor: actor)
    end

    def command(debit:, credit:, source_type: nil, source_id: nil, action: nil)
      AccountingEngine::Command.new(
        ledger: @ledger,
        effective_date: Date.current,
        source_type: source_type,
        source_id: source_id,
        action: action,
        lines: [
          AccountingEngine::Command::Line.new(account: @cash, debit: debit, credit: 0),
          AccountingEngine::Command::Line.new(account: @income, debit: 0, credit: credit)
        ]
      )
    end
end
