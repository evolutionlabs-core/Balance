class Engine::Receipt < Data.define(:entry, :errors, :verdict, :warnings)
  def success? = !entry.nil?
end
