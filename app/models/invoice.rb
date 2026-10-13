class Invoice < ApplicationRecord
  include AASM
  include Invoices::Posting

  STATUSES = %w[draft sent paid voided].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :estimate, optional: true
  belongs_to :project, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy
  has_many :payments, class_name: "InvoicePayment", dependent: :restrict_with_error

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :blank_line_attributes?

  validates :status, inclusion: { in: STATUSES }
  validates :customer, presence: true, unless: -> { validation_context == :editing }
  validates :invoice_number, uniqueness: { scope: :workspace_id }, allow_nil: true
  validate :at_least_one_line, if: -> { @invoice_lines_submitted }
  validate :customer_belongs_to_workspace

  generates_token_for :client_view, expires_in: 90.days do
    [ workspace_id, status, invoice_number ]
  end

  before_validation :populate_party_details, on: :create
  before_validation :calculate_totals
  after_create :assign_invoice_number, if: -> { invoice_number.blank? }
  before_update { throw(:abort) if content_frozen? }
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

  def balance_due_kobo
    [ total_minor - applied_amount_kobo, 0 ].max
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
    def fully_paid?
      balance_due_kobo.zero?
    end

    def nothing_applied?
      applied_amount_kobo.zero?
    end

    def content_frozen?
      status_in_database != "draft" && content_changed?
    end

    def content_changed?
      (changes.keys - %w[status updated_at]).any?
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
      self.total_minor = subtotal_minor
    end

    def active_lines
      invoice_lines.reject(&:marked_for_destruction?)
    end
end
