class Accounting::Receipt < Data.define(:entry, :errors, :warnings)
  def self.rejected(errors)
    new(nil, errors.freeze, [].freeze)
  end

  def success? = !entry.nil?
end
