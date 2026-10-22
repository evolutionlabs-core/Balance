module AccountingEngine::Validation
  def self.call(command)
    ExistenceCheck.call(command) + MathCheck.call(command) + AmountCheck.call(command) + CounterpartyCheck.call(command) + ReversalCheck.call(command)
  end
end
