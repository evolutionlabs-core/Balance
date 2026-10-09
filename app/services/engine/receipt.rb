class Engine::Receipt < Data.define(:entry, :errors, :verdict)
  # Success means a row was actually written. A paused command has no errors
  # but is not a success either.
  def success? = !entry.nil?
end
