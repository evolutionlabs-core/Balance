class Accounting::Policies::InvoiceIssued::V1
  AccountSnapshot = Data.define(:invoice_line_id, :account_id)
  Result = Data.define(:plan, :account_snapshots, :errors) do
    def success? = errors.empty?
  end

  def self.call(invoice:, account_resolver: Accounting::InvoiceAccountResolver.new)
    new(invoice, account_resolver).call
  end

  def initialize(invoice, account_resolver)
    @invoice = invoice
    @account_resolver = account_resolver
  end

  def call
    resolution = account_resolver.resolve(invoice)
    unless resolution.success?
      return Result.new(plan: nil, account_snapshots: [].freeze, errors: resolution.errors)
    end

    credit_lines = invoice.invoice_lines.map do |line|
      account_id = resolution.income_account_ids.fetch(line.id)
      Accounting::PostingPlan::Line.new(
        account_id: account_id,
        debit_kobo: 0,
        credit_kobo: line.amount_minor
      )
    end
    receivable_line = Accounting::PostingPlan::Line.new(
      account_id: resolution.receivable_account_id,
      debit_kobo: invoice.total_minor,
      credit_kobo: 0,
      counterparty_type: "Customer",
      counterparty_id: invoice.customer_id
    )
    plan = Accounting::PostingPlan.new(
      workspace_id: invoice.workspace_id,
      entry_date: invoice.issue_date || Date.current,
      description: "Invoice #{invoice.invoice_number}",
      lines: credit_lines.push(receivable_line)
    )
    snapshots = resolution.income_account_ids.map do |invoice_line_id, account_id|
      AccountSnapshot.new(invoice_line_id:, account_id:)
    end.freeze

    Result.new(plan:, account_snapshots: snapshots, errors: [].freeze)
  end

  private
    attr_reader :invoice, :account_resolver
end
