class AccountingEngine::Receipt < Data.define(:entry, :errors, :replayed)
  def self.posted(entry)
    new(entry, [].freeze, false)
  end

  def self.replayed(entry)
    new(entry, [].freeze, true)
  end

  def self.rejected(errors)
    new(nil, errors.map { |error| error.is_a?(AccountingEngine::Error) ? error : AccountingEngine::Error.new(:rejected, error.to_s) }.freeze, false)
  end

  def success? = !entry.nil?

  def replayed? = replayed
end
