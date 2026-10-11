module Engine::PeriodState
  Error = Data.define(:check, :message) do
    def to_s = message
  end
end
