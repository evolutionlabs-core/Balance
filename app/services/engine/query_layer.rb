class Engine::QueryLayer
  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query
  end

  # Reads are not gated on ledger status: a closed ledger still has to report.
  #
  # The snapshot is the as_of date, which every stage shares, so balances and
  # history describe the same point in time. Posted entries and lines are
  # immutable, so no isolation level is needed to make that stable. Relations
  # are materialised here rather than handed back lazy, so the result is a
  # value and cannot re-query later at a different as_of.
  def call
    balances = Engine::BalanceAggregator.call(query)

    Engine::QueryResult.new(
      ledger: query.ledger,
      as_of: query.as_of,
      balances: balances.freeze,
      entries: Engine::HistoryBuilder.call(query).to_a.freeze,
      trial_balance: Engine::ReportComposer.trial_balance(balances).freeze
    )
  end

  private
    attr_reader :query
end
