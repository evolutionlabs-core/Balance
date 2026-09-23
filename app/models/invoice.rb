class Invoice < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :estimate, optional: true
  belongs_to :project, optional: true
  belongs_to :journal_entry, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy
  has_many :receivable_applications, dependent: :restrict_with_error

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :blank_line_attributes?

  validates :customer, presence: true, unless: -> { validation_context == :editing }
  validates :invoice_number, uniqueness: { scope: :workspace_id }, allow_nil: true
  validate :at_least_one_line, if: -> { @invoice_lines_submitted }
  validate :customer_belongs_to_workspace

  enum :status, { draft: "draft", posted: "posted" }, validate: true

  before_validation :populate_party_details, on: :create
  before_validation :calculate_totals
  after_create :assign_invoice_number, if: -> { invoice_number.blank? }
  before_update { throw(:abort) if status_in_database == "posted" }
  before_destroy { throw(:abort) if posted? }

  # Negative form indexes identify saved rows; omitted saved rows are removed on save.
  def invoice_lines_attributes=(attributes)
    @invoice_lines_submitted = true
    if attributes.is_a?(Hash) && attributes.keys.any? { |key| key.to_s.start_with?("-") }
      retained_ids = attributes.keys.filter_map { |key| key.to_s.delete_prefix("-").to_i if key.to_s.start_with?("-") }
      invoice_lines.each { |line| line.mark_for_destruction unless retained_ids.include?(line.id) }
      attributes = attributes.transform_keys(&:to_s).transform_values(&:to_h)
      attributes.each do |key, values|
        values["id"] = key.delete_prefix("-") if key.start_with?("-")
      end
    end
    super(attributes)
  end

  def use_customer_details
    self.bill_to_name = customer&.name
    self.bill_to_email = customer&.email
    self.bill_to_address = customer&.address
  end

  def add_line(attributes = {})
    line = invoice_lines.build(attributes)
    save(context: :editing)
    line
  end

  def change_line(id, attributes, context = nil)
    assign_attributes(invoice_lines_attributes: [ attributes.merge(id: id) ])
    save(context: context)
  end

  def remove_line(id)
    transaction do
      line = invoice_lines.find(id)
      line.destroy!
      invoice_lines.reset
      save!(context: :editing)
      line
    end
  end

  def change_customer(new_customer)
    self.customer = new_customer
    use_customer_details
    save!
  end

  def post(receivable_account:, line_accounts: [])
    result = nil
    with_lock do
      if posted?
        errors.add(:base, "has already been posted")
        return Accounting::PostingService::Result.new(nil, errors.full_messages, nil)
      end

      invoice_lines.reset
      invoice_lines.lock.load
      self.invoice_lines_attributes = line_accounts if line_accounts.present?
      valid?
      validate_posting_accounts(receivable_account)
      if errors.any?
        return Accounting::PostingService::Result.new(nil, errors.full_messages.uniq, nil)
      end

      save!
      result = Accounting::PostingService.call(source: self, entry_builder: -> { journal_entry_draft(receivable_account) })
      raise ActiveRecord::Rollback unless result.success?
    end
    result
  end

  def record_posting!(entry)
    update!(journal_entry: entry, status: :posted)
  end

  def applied_amount_kobo
    if receivable_applications.loaded?
      receivable_applications.sum(&:effective_amount_kobo)
    else
      receivable_applications.sum(
        Arel.sql("CASE WHEN reverses_receivable_application_id IS NULL THEN amount_kobo ELSE -amount_kobo END")
      )
    end
  end

  def balance_due_kobo
    [ total_minor - applied_amount_kobo, 0 ].max
  end

  def record_receipt(account:, received_on:, amount_kobo:)
    self.class.transaction do
      workspace.invoices.posted.where(customer_id: customer_id).order(:id).lock.load
      receivable_applications.reset
      errors.clear
      validate_receipt(account, amount_kobo)
      return failed_posting_result if errors.any?

      receivable_account = Account.for_role!(workspace, :receivable)
      entry = workspace.journal_entries.build(
        entry_date: received_on,
        description: "Payment received for invoice #{invoice_number}",
        journal_entry_lines_attributes: [
          { account: account, debit_kobo: amount_kobo, credit_kobo: 0 },
          { account: receivable_account, debit_kobo: 0, credit_kobo: amount_kobo, counterparty: customer }
        ]
      )
      Accounting::PostingService.call(entry: entry, allocation_invoice: self)
    end
  end

  def refresh_business_details
    self.business_name = workspace.name
    self.business_email = user.email_address
    self.business_address = workspace.address
    save!
  end

  def populate_party_details
    self.business_name = workspace.name if business_name.nil?
    self.business_email = user.email_address if business_email.nil?
    self.business_address = workspace.address if business_address.nil?

    if customer
      self.bill_to_name = customer.name if bill_to_name.nil?
      self.bill_to_email = customer.email if bill_to_email.nil?
      self.bill_to_address = customer.address if bill_to_address.nil?
    end
  end

  private
    def customer_belongs_to_workspace
      return if customer.blank? || customer.workspace_id == workspace_id

      errors.add(:customer, "must belong to the workspace")
    end

    def blank_line_attributes?(attributes)
      return false if attributes["id"].present? || attributes[:id].present?

      attributes.values_at("service_id", :service_id, "service", :service, "description", :description).all?(&:blank?) &&
        attributes.fetch("rate", attributes.fetch(:rate, 0)).to_d.zero? &&
        attributes.fetch("amount", attributes.fetch(:amount, 0)).to_d.zero?
    end

    def at_least_one_line
      errors.add(:invoice_lines, "must include at least one item") if active_lines.empty?
    end

    def assign_invoice_number
      self.invoice_number = format("INV-%06d", id)
      update_column(:invoice_number, invoice_number)
    end

    def validate_posting_accounts(receivable_account)
      if receivable_account.blank? || receivable_account.workspace_id != workspace_id
        errors.add(:base, "receivable account must belong to the workspace")
      elsif receivable_account.role != "receivable"
        errors.add(:base, "receivable account must be Accounts Receivable")
      end

      invoice_lines.each do |line|
        if line.account.blank?
          errors.add(:base, "every invoice line must have an income account")
        elsif line.account.workspace_id != workspace_id || line.account.base_type != "income"
          errors.add(:base, "every invoice line account must be workspace income")
        end
      end
    end

    def validate_receipt(account, amount_kobo)
      errors.add(:base, "invoice must be issued before recording payment") unless posted?
      errors.add(:base, "invoice has no outstanding balance") if balance_due_kobo.zero?
      unless account && workspace.receipt_accounts.exists?(id: account.id)
        errors.add(:base, "payment account must be a Bank or Cash account in this workspace")
      end
      unless amount_kobo.is_a?(Integer) && amount_kobo.positive? && amount_kobo <= balance_due_kobo
        errors.add(:base, "payment amount must be positive and no more than the balance due")
      end
    end

    def failed_posting_result
      Accounting::PostingService::Result.new(nil, errors.full_messages.uniq, nil)
    end

    def journal_entry_draft(receivable_account)
      workspace.journal_entries.build(
        entry_date: issue_date || Date.current,
        description: "Invoice #{invoice_number}",
        journal_entry_lines_attributes:
          invoice_lines.map do |line|
            { account: line.account, debit_kobo: 0, credit_kobo: line.amount_minor }
          end.push(account: receivable_account, debit_kobo: total_minor, credit_kobo: 0, counterparty: customer)
      )
    end

    def calculate_totals
      active_lines.each_with_index do |line, position|
        line.position = position
        line.calculate_amount
      end

      self.subtotal_minor = active_lines.sum { |line| line.amount_minor || 0 }
      self.total_minor = subtotal_minor
    end

    def active_lines
      invoice_lines.reject(&:marked_for_destruction?)
    end
end
