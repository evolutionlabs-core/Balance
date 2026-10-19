module AccountingEngine::Validation
  Result = Data.define(:errors) do
    def ok? = errors.empty?
  end
end
