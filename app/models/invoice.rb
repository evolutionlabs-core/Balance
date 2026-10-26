class Invoice < ApplicationRecord
  include WorkspaceCurrency
  include AASM
  include Invoices::Posting
  include Invoices::Discount

  STATUSES = %w[draft sent paid voided].freeze
  EDITABLE_AFTER_SENDING = %w[payment_terms due_date reference bill_to_email notes internal_note].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :estimate, optional: true
  belongs_to :project, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy
  has_many :payments, class_name: "InvoicePayment", dependent: :restrict_with_error
  has_many :credit_notes, -> { order(:id) }, dependent: :restrict_with_error
  has_many :revisions, -> { order(:created_at, :id) }, class_name: "InvoiceRevision", dependent: :restrict_with_error

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :blank_line_attributes?

  validates :status, inclusion: { in: STATUSES }
  validates :customer, presence: true, unless: -> { validation_context == :editing }
  validates :invoice_number, uniqueness: { scope: :workspace_id }, allow_nil: true
  validates :payment_terms, inclusion: { in: PaymentTerms.keys }, allow_nil: true
  validate :at_least_one_line, if: -> { @invoice_lines_submitted }
  validate :customer_belongs_to_workspace
  validates :bill_to_email, email: true, on: :revision
  validate :due_date_not_before_issue_date, on: :revision

  scope :outstanding, -> { where(status: "sent") }
  scope :overdue, ->(on = Date.current) { outstanding.where(due_date: ...on) }
  scope :not_due, ->(on = Date.current) { outstanding.where("invoices.due_date IS NULL OR invoices.due_date >= ?", on) }

  generates_token_for :client_view, expires_in: 90.days do
    [ workspace_id, invoice_number ]
  end

  before_validation :populate_party_details, :apply_workspace_defaults, on: :create
  before_validation :apply_payment_terms
  before_validation :calculate_totals
  after_create :assign_invoice_number, if: -> { invoice_number.blank? }
  before_update :ensure_content_editable
  before_destroy { throw(:abort) unless draft? }

  aasm column: :status do
    state :draft, initial: true
    state :sent, :paid, :voided

    event :send_to_client do
      transitions from: :draft, to: :sent
    end

    event :pay do
      transitions from: :sent, to: :paid, guard: :fully_paid?
    end

    event :reopen do
      transitions from: :paid, to: :sent, guard: -> { !fully_paid? }
    end

    event :mark_voided do
      transitions from: :draft, to: :voided
      transitions from: :sent, to: :voided, guard: :nothing_applied?
    end
  end

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

  def revisable?
    sent? || paid?
  end

  def revise(attributes, user:)
    @revising = true
    assign_attributes(attributes.to_h.slice(*EDITABLE_AFTER_SENDING))

    transaction do
      raise ActiveRecord::Rollback unless save(context: :revision)

      field_changes = saved_changes.slice(*EDITABLE_AFTER_SENDING).reject { |_field, (from, to)| from.blank? && to.blank? }
      revisions.create!(workspace: workspace, user: user, field_changes: field_changes) if field_changes.any?
      true
    end.present?
  ensure
    @revising = false
  end

  def change_customer(new_customer)
    self.customer = new_customer
    use_customer_details
    save!
  end

  def applied_amount_kobo
    if payments.loaded?
      payments.sum(&:effective_amount_kobo)
    else
      payments.sum(
        Arel.sql("CASE WHEN reverses_invoice_payment_id IS NULL THEN amount_kobo ELSE -amount_kobo END")
      )
    end
  end

  def credited_amount_minor
    if credit_notes.loaded?
      credit_notes.reject(&:voided?).sum(&:amount_minor)
    else
      credit_notes.active.sum(:amount_minor)
    end
  end

  def balance_due_kobo
    [ total_minor - applied_amount_kobo - credited_amount_minor, 0 ].max
  end

  def overdue?(on = Date.current)
    sent? && due_date.present? && due_date < on && balance_due_kobo.positive?
  end

  def days_overdue(on = Date.current)
    overdue?(on) ? (on - due_date).to_i : 0
  end

  def refresh_business_details
    self.business_name = workspace.name
    self.business_email = user.email_address
    self.business_address = workspace.address
    save!
  end

  def duplicate(user:)
    copy = workspace.invoices.build(
      user: user, customer: customer, project: project, currency_code: currency_code, issue_date: Date.current,
      payment_terms: (payment_terms if PaymentTerms::DAYS.key?(payment_terms)),
      notes: notes, payment_instructions: payment_instructions,
      discount_type: discount_type, discount_value: discount_value
    )
    invoice_lines.each do |line|
      copy.invoice_lines.build(line.slice(:service_id, :account_id, :description, :quantity, :rate_minor, :amount_minor))
    end
    copy
  end

  def apply_workspace_defaults
    self.payment_terms ||= due_date.present? ? "custom" : workspace.default_payment_terms
    self.notes = workspace.default_invoice_note if notes.nil?
    self.payment_instructions = workspace.payment_instructions if payment_instructions.nil?
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
    def apply_payment_terms
      return if payment_terms.nil?

      if due_date_changed? && !payment_terms_changed? && !issue_date_changed?
        self.payment_terms = "custom"
      elsif (due = PaymentTerms.due_date(payment_terms, issue_date))
        self.due_date = due
      end
    end

    def fully_paid?
      balance_due_kobo.zero?
    end

    def nothing_applied?
      applied_amount_kobo.zero? && credited_amount_minor.zero?
    end

    def ensure_content_editable
      if content_frozen?
        errors.add(:base, "Only the terms, due date, reference, billing email and notes can change after an invoice is sent")
        throw(:abort)
      end
    end

    def content_frozen?
      changed_content = changes.keys - %w[status updated_at]

      case status_in_database
      when "draft" then false
      when "sent", "paid" then (changed_content - (@revising ? EDITABLE_AFTER_SENDING : [])).any?
      else changed_content.any?
      end
    end

    def due_date_not_before_issue_date
      return if due_date.nil? || due_date >= issue_date

      errors.add(:due_date, "can't be before the invoice date")
    end

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

    def calculate_totals
      active_lines.each_with_index do |line, position|
        line.position = position
        line.calculate_amount
      end

      self.subtotal_minor = active_lines.sum { |line| line.amount_minor || 0 }
      calculate_discount
      self.total_minor = subtotal_minor - discount_minor
    end

    def active_lines
      invoice_lines.reject(&:marked_for_destruction?)
    end
end
