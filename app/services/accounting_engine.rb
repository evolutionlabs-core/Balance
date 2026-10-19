module AccountingEngine
  def self.post(command)
    Posting.call(command)
  end

  def self.record(builder, workspace:, attributes:, source_id:, description: nil)
    post(builder.call(workspace: workspace, attributes: attributes, source_id: source_id, description: description))
  rescue Builders::AccountMissing => error
    Receipt.rejected([ error.message ])
  rescue ActiveRecord::RecordNotUnique
    Receipt.rejected([ "This #{builder.name.demodulize.titleize.downcase} has already been recorded." ])
  end

  def self.read(spec)
    Query.call(**spec)
  end
end
