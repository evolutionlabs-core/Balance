module Engine::PeriodState
  def self.call(command)
    Result.new(LedgerStatus.call(command).freeze)
  end
end
