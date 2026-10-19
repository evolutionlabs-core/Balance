module Accounting
  def self.post(command)
    PostingOrchestrator.call(command)
  end

  def self.read(spec)
    Query.call(**spec)
  end
end
