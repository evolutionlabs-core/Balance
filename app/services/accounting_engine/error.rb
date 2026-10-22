module AccountingEngine
  Error = Data.define(:code, :message) do
    def to_s = message
  end
end
