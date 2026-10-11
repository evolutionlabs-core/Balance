module Engine::Validation
  Result = Data.define(:errors, :command) do
    def ok? = errors.empty?
  end
end
