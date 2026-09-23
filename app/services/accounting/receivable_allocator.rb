class Accounting::ReceivableAllocator
  def self.call(journal_entry)
    new(journal_entry).call
  end

  def initialize(journal_entry)
    @journal_entry = journal_entry
  end

  def call
    if journal_entry.reverses_journal_entry_id?
      reverse_original_applications
    elsif customer_receipt?
      allocate_receipt
    end
  end

  private
    attr_reader :journal_entry

    def reverse_original_applications
      journal_entry.reverses_journal_entry.receivable_applications.find_each do |application|
        journal_entry.receivable_applications.create!(
          workspace: journal_entry.workspace,
          invoice: application.invoice,
          amount_kobo: application.amount_kobo,
          reverses_receivable_application: application
        )
      end
    end

    def customer_receipt?
      lines = journal_entry.journal_entry_lines
      debit_lines = lines.select { |line| line.debit_kobo.positive? }
      credit_lines = lines.select { |line| line.credit_kobo.positive? }

      debit_lines.any? && credit_lines.any? &&
        debit_lines.all? { |line| cash_account?(line.account) } &&
        credit_lines.all? { |line| receivable_customer_line?(line) }
    end

    def cash_account?(account)
      account.workspace_id == journal_entry.workspace_id &&
        account.base_type == "asset" &&
        account.role != "suspense" &&
        cash_account_types.include?(account.account_type)
    end

    def cash_account_types
      if journal_entry.workspace.business?
        [ "Bank" ]
      else
        [ "Cash & Liquid Assets" ]
      end
    end

    def receivable_customer_line?(line)
      line.account.role == "receivable" &&
        line.counterparty_type == "Customer" &&
        line.counterparty&.workspace_id == journal_entry.workspace_id
    end

    def allocate_receipt
      receivable_credits.group_by(&:counterparty).each do |customer, lines|
        allocate_customer(customer, lines.sum(&:credit_kobo))
      end
    end

    def receivable_credits
      journal_entry.journal_entry_lines.select { |line| line.credit_kobo.positive? }
    end

    def allocate_customer(customer, amount_kobo)
      remaining_kobo = amount_kobo
      invoices = journal_entry.workspace.invoices.posted.where(customer: customer).order(:issue_date, :id).lock

      invoices.each do |invoice|
        break if remaining_kobo.zero?

        amount = [ invoice.balance_due_kobo, remaining_kobo ].min
        next if amount.zero?

        journal_entry.receivable_applications.create!(
          workspace: journal_entry.workspace,
          invoice: invoice,
          amount_kobo: amount
        )
        remaining_kobo -= amount
      end
    end
end
