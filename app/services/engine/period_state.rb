module Engine::PeriodState
  def self.call(command)
    command.ledger.lock!

    errors = (
      LedgerStatus.call(command) +
      AccountStatus.call(command) +
      PeriodStatus.call(command)
    ).freeze

    Result.new(errors)
  end
end
