module AccountingEngine
  def self.post(command)
    Posting.call(command)
  end

  def self.record(builder, workspace:, attributes:, source_id:, description: nil)
    post(builder.call(workspace: workspace, attributes: attributes, source_id: source_id, description: description))
  rescue Builders::AccountMissing => error
    Receipt.rejected([ Error.new(:account_missing, error.message) ])
  end

  def self.read(spec)
    Query.call(**spec)
  end
end
