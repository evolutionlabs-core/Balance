module AccountingEngine::PeriodState
  def self.call(command)
    Result.new((LedgerStatus.call(command) + AccountStatus.call(command) + PeriodStatus.call(command)).freeze)
  end
end
