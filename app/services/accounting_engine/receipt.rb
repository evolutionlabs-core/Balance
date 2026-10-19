class AccountingEngine::Receipt < Data.define(:entry, :errors, :warnings, :replayed)
  def self.posted(entry, warnings: [])
    new(entry, [].freeze, warnings.freeze, false)
  end

  def self.replayed(entry)
    new(entry, [].freeze, [].freeze, true)
  end

  def self.rejected(errors, warnings: [])
    new(nil, errors.map { |error| error.is_a?(AccountingEngine::Error) ? error : AccountingEngine::Error.new(:rejected, error.to_s) }.freeze, warnings.freeze, false)
  end

  def success? = !entry.nil?

  def replayed? = replayed
end
