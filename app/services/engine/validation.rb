module Engine::Validation
  def self.call(command)
    structural = StructureCheck.call(command)
    return Result.new(structural.freeze, nil) if structural.any?

    errors = (ExistenceCheck.call(command) + MathCheck.call(command) + AmountCheck.call(command)).freeze
    Result.new(errors, errors.empty? ? Normalizer.call(command) : nil)
  end
end
