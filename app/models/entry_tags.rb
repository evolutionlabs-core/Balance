module EntryTags
  LIMIT = 10
  LENGTH = 30

  def self.parse(value)
    Array(value.is_a?(String) ? value.split(",") : value)
      .map { |tag| tag.to_s.strip.downcase.squish.first(LENGTH) }
      .compact_blank.uniq.first(LIMIT)
  end
end
