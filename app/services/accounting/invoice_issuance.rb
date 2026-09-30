class Accounting::InvoiceIssuance
  Result = Data.define(:entry, :errors, :proof) do
    def success? = errors.empty?
  end

  def self.call(invoice:, policy: Accounting::Policies::InvoiceIssued::V1,
    account_resolver: Accounting::InvoiceAccountResolver.new, posting_service: Accounting::PostingService)
    new(invoice, policy:, account_resolver:, posting_service:).call
  end

  def initialize(invoice, policy:, account_resolver:, posting_service:)
    @invoice = invoice
    @policy = policy
    @account_resolver = account_resolver
    @posting_service = posting_service
  end

  def call
    result = nil

    Invoice.transaction do
      invoice.lock!
      if invoice.posted?
        invoice.errors.add(:base, "has already been posted")
        result = failed_result
        raise ActiveRecord::Rollback
      end

      invoice.invoice_lines.reset
      invoice.invoice_lines.lock.load
      unless invoice.valid?
        result = failed_result
        raise ActiveRecord::Rollback
      end

      policy_result = policy.call(invoice:, account_resolver:)
      unless policy_result.success?
        policy_result.errors.each { |error| invoice.errors.add(:base, error.message) }
        result = failed_result
        raise ActiveRecord::Rollback
      end

      snapshot_accounts(policy_result.account_snapshots)
      entry = build_entry(policy_result.plan)
      posting_result = posting_service.call(entry:, source: invoice)
      result = Result.new(entry: posting_result.entry, errors: posting_result.errors, proof: posting_result.proof)
      raise ActiveRecord::Rollback unless result.success?
    end

    result
  end

  private
    attr_reader :invoice, :policy, :account_resolver, :posting_service

    def snapshot_accounts(snapshots)
      lines_by_id = invoice.invoice_lines.index_by(&:id)
      snapshots.each do |snapshot|
        line = lines_by_id.fetch(snapshot.invoice_line_id)
        line.update!(account_id: snapshot.account_id) if line.account_id != snapshot.account_id
      end
    end

    def build_entry(plan)
      accounts = invoice.workspace.accounts.where(id: plan.lines.map(&:account_id)).index_by(&:id)
      invoice.workspace.journal_entries.build(
        entry_date: plan.entry_date,
        description: plan.description,
        journal_entry_lines_attributes: plan.lines.map do |line|
          {
            account: accounts.fetch(line.account_id),
            debit_kobo: line.debit_kobo,
            credit_kobo: line.credit_kobo,
            counterparty: counterparty_for(line)
          }
        end
      )
    end

    def counterparty_for(line)
      if line.counterparty_type == "Customer" && line.counterparty_id == invoice.customer_id
        invoice.customer
      end
    end

    def failed_result
      Result.new(entry: nil, errors: invoice.errors.full_messages.uniq.freeze, proof: nil)
    end
end
