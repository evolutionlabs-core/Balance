module AccountingEngine::PeriodState
  Result = Data.define(:errors) do
    def ok? = errors.empty?
  end
end
