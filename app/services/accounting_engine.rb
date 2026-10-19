module AccountingEngine
  def self.post(command)
    Posting.call(command)
  end

  def self.read(spec)
    Query.call(**spec)
  end
end
