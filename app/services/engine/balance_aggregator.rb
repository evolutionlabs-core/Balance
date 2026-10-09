class Engine::BalanceAggregator
  Balance = Data.define(:ledger_account, :net)

  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query
  end

  def call
    nets = net_by_account_id

    account_scope.map do |account|
      Balance.new(ledger_account: account, net: nets.fetch(account.id, BigDecimal(0)))
    end
  end

  private
    attr_reader :query

    # Net is debit minus credit, so the sign is relative to the account's
    # normal balance: positive for debit-normal, negative for credit-normal.
    def net_by_account_id
      LedgerLine.joins(:ledger_entry)
        .where(ledger_entries: { ledger_id: query.ledger.id, effective_date: ..query.as_of })
        .where(ledger_account_id: account_scope.select(:id))
        .group(:ledger_account_id)
        .pluck(:ledger_account_id, Arel.sql("SUM(ledger_lines.debit) - SUM(ledger_lines.credit)"))
        .to_h
    end

    def account_scope
      if query.account_ids
        query.ledger.ledger_accounts.where(id: query.account_ids).ordered
      else
        query.ledger.ledger_accounts.ordered
      end
    end
end
