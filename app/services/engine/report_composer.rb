class Engine::ReportComposer
  TrialBalanceLine = Data.define(:ledger_account, :debit, :credit)

  def self.trial_balance(balances)
    new(balances).trial_balance
  end

  def initialize(balances)
    @balances = balances
  end

  def trial_balance
    balances.filter_map do |balance|
      next if balance.net.zero?

      if balance.net.positive?
        TrialBalanceLine.new(ledger_account: balance.ledger_account, debit: balance.net, credit: BigDecimal(0))
      else
        TrialBalanceLine.new(ledger_account: balance.ledger_account, debit: BigDecimal(0), credit: -balance.net)
      end
    end
  end

  private
    attr_reader :balances
end
