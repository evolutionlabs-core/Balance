module PaymentTerms
  DAYS = { "due_on_receipt" => 0, "net_7" => 7, "net_15" => 15, "net_30" => 30, "net_60" => 60 }.freeze

  LABELS = {
    "due_on_receipt" => "Due on receipt",
    "net_7" => "Net 7",
    "net_15" => "Net 15",
    "net_30" => "Net 30",
    "net_60" => "Net 60",
    "custom" => "Custom"
  }.freeze

  def self.keys
    LABELS.keys
  end

  def self.due_date(terms, issue_date)
    issue_date + DAYS.fetch(terms) if issue_date && DAYS.key?(terms)
  end

  def self.label(terms)
    LABELS[terms]
  end

  def self.choices(include_custom: true)
    (include_custom ? LABELS : LABELS.except("custom")).invert
  end
end
