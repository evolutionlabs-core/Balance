class AccountingEngine::GeneralLedger
  Line = Data.define(:entry, :debit, :credit, :balance, :counterparty)

  attr_reader :account, :from, :to

  def initialize(account, from:, to: Date.current)
    @account = account
    @from = from
    @to = to
  end

  def opening_balance
    @opening_balance ||= sign * balances.by_account(..(from - 1)).fetch(account.id, 0)
  end

  def lines
    @lines ||= begin
      running = opening_balance

      balances.activity(account, from..to).map do |line|
        running += sign * (line.debit - line.credit)
        Line.new(entry: line.journal_entry, debit: line.debit, credit: line.credit, balance: running, counterparty: line.customer || line.vendor)
      end
    end
  end

  def closing_balance
    lines.last&.balance || opening_balance
  end

  private
    def balances
      @balances ||= AccountingEngine::Balances.new(account.ledger)
    end

    def sign
      account.normal_balance == "debit" ? 1 : -1
    end
end
