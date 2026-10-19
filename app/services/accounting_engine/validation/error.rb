module AccountingEngine::Validation
  Error = Data.define(:check, :message) do
    def to_s = message
  end
end
