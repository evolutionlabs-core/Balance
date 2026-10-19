module Accounting::Validation
  def self.call(command)
    structural = StructureCheck.call(command)
    return Result.new(structural.freeze) if structural.any?

    Result.new((ExistenceCheck.call(command) + MathCheck.call(command) + AmountCheck.call(command) + CounterpartyCheck.call(command) + ReversalCheck.call(command)).freeze)
  end
end
