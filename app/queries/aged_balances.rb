class AgedBalances
  BUCKETS = {
    current: "Current",
    days_1_30: "1–30 days",
    days_31_60: "31–60 days",
    days_61_90: "61–90 days",
    over_90: "Over 90 days"
  }.freeze

  # A counterparty's open documents by age, beside what the control account
  # in the ledger says they owe or are owed. A nil counterparty collects
  # control-account lines that name nobody.
  Row = Data.define(:counterparty, :buckets, :total_kobo, :ledger_kobo) do
    def tied_out? = total_kobo == ledger_kobo
  end

  def initialize(workspace, side:, as_of: Date.current)
    @workspace = workspace
    @side = side
    @as_of = as_of
  end

  def rows
    @rows ||= (open_by_counterparty.keys | ledger_by_counterparty.keys).map do |id|
      documents = open_by_counterparty.fetch(id, [])
      buckets = BUCKETS.keys.index_with { 0 }
      documents.each { |document| buckets[bucket_for(document)] += document.balance_due_kobo }

      Row.new(
        counterparty: counterparties[id],
        buckets: buckets,
        total_kobo: buckets.values.sum,
        ledger_kobo: ledger_by_counterparty.fetch(id, 0)
      )
    end.sort_by { |row| [ -row.total_kobo, row.counterparty&.name.to_s ] }
  end

  def bucket_totals
    BUCKETS.keys.index_with { |bucket| rows.sum { |row| row.buckets[bucket] } }
  end

  def total_kobo
    rows.sum(&:total_kobo)
  end

  def ledger_kobo
    rows.sum(&:ledger_kobo)
  end

  def tied_out?
    rows.all?(&:tied_out?)
  end

  def unmatched_rows
    rows.reject(&:tied_out?)
  end

  private
    attr_reader :workspace, :side, :as_of

    def open_by_counterparty
      @open_by_counterparty ||= open_documents
        .select { |document| document.balance_due_kobo.positive? }
        .group_by { |document| document.public_send(counterparty_key) }
    end

    def open_documents
      case side
      when :receivables then workspace.invoices.where(status: "sent").includes(:payments)
      when :payables then workspace.bills.where(status: "open").includes(:payments)
      end
    end

    def bucket_for(document)
      days_overdue = (as_of - due_on(document)).to_i

      if days_overdue <= 0 then :current
      elsif days_overdue <= 30 then :days_1_30
      elsif days_overdue <= 60 then :days_31_60
      elsif days_overdue <= 90 then :days_61_90
      else :over_90
      end
    end

    def due_on(document)
      case side
      when :receivables then document.due_date || document.issue_date
      when :payables then document.due_date || document.bill_date
      end
    end

    # Receivables carry debit balances and payables credit balances; both are
    # reported as positive amounts owed.
    def ledger_by_counterparty
      @ledger_by_counterparty ||= AccountingEngine::Balances.new(workspace.ledger)
        .by_counterparty(side == :receivables ? :customer : :vendor, subtype: control_subtype)
        .transform_values { |raw| side == :receivables ? raw : -raw }
        .reject { |_id, balance| balance.zero? }
    end

    def counterparties
      @counterparties ||= counterparty_scope.where(id: open_by_counterparty.keys | ledger_by_counterparty.keys).index_by(&:id)
    end

    def counterparty_scope
      side == :receivables ? workspace.customers : workspace.vendors
    end

    def counterparty_key
      side == :receivables ? :customer_id : :vendor_id
    end

    def control_subtype
      side == :receivables ? "accounts_receivable" : "accounts_payable"
    end
end
