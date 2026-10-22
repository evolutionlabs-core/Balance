module AccountingEngine::PeriodState
  def self.call(command)
    LedgerStatus.call(command) + AccountStatus.call(command) + PeriodStatus.call(command)
  end
end
