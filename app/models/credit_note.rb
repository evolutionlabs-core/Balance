class CreditNote < ApplicationRecord
  include WorkspaceCurrency
  include Invoices::Discount
  include CreditNotes::Posting

  STAMPED_ATTRIBUTES = %w[journal_entry_id void_journal_entry_id voided_at].freeze

  belongs_to :workspace
  belongs_to :customer
  belongs_to :user
  belongs_to :invoice, optional: true
  belongs_to :journal_entry, optional: true
  belongs_to :void_journal_entry, class_name: "JournalEntry", optional: true
  has_many :lines, -> { order(:position) }, class_name: "CreditNoteLine", inverse_of: :credit_note
  has_many :applications, class_name: "CreditApplication", dependent: :restrict_with_error

  accepts_nested_attributes_for :lines, reject_if: :blank_line_attributes?

  validates :issued_on, presence: true
  validate :at_least_one_line, on: :create
  validate :customer_belongs_to_workspace
  validate :invoice_belongs_to_customer

  scope :ordered, -> { order(issued_on: :desc, id: :desc) }
  scope :active, -> { where(voided_at: nil) }

  before_validation :use_customer_details, on: :create
  before_validation :calculate_totals, on: :create
  after_create :assign_number
  before_update { throw(:abort) unless stamping? }
  before_destroy { throw(:abort) }

  def self.from_invoice(invoice, user:)
    credit_note = invoice.workspace.credit_notes.build(
      user: user, customer: invoice.customer, invoice: invoice, issued_on: Date.current, currency_code: invoice.currency_code,
      bill_to_name: invoice.bill_to_name, bill_to_email: invoice.bill_to_email, bill_to_address: invoice.bill_to_address,
      subtotal_minor: invoice.subtotal_minor, discount_minor: invoice.discount_minor, total_minor: invoice.total_minor
    )
    invoice.invoice_lines.each do |line|
      credit_note.lines.build(service_id: line.service_id, account_id: line.account_id, description: line.description,
        quantity: line.quantity, rate_minor: line.rate_minor, amount: line.amount)
    end
    credit_note
  end

  def voided?
    voided_at.present?
  end

  def applied_minor
    if applications.loaded?
      applications.sum(&:amount_minor)
    else
      applications.sum(:amount_minor)
    end
  end

  def unapplied_minor
    voided? ? 0 : total_minor - applied_minor
  end

  private
    def use_customer_details
      return if customer.nil?

      self.bill_to_name = customer.name if bill_to_name.nil?
      self.bill_to_email = customer.email if bill_to_email.nil?
      self.bill_to_address = customer.address if bill_to_address.nil?
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

    def calculate_discount
      self.discount_minor = if invoice&.discounted?
        (invoice.discount_minor * subtotal_minor / invoice.subtotal_minor.to_r).round
      else
        0
      end
    end

    def active_lines
      lines.reject(&:marked_for_destruction?)
    end

    def at_least_one_line
      errors.add(:base, "Add at least one line") if active_lines.empty?
    end

    def customer_belongs_to_workspace
      return if customer.blank? || customer.workspace_id == workspace_id

      errors.add(:customer, "must belong to the workspace")
    end

    def invoice_belongs_to_customer
      return if invoice.blank? || invoice.customer_id == customer_id

      errors.add(:invoice, "must belong to the same customer")
    end

    def blank_line_attributes?(attributes)
      attributes.values_at("service_id", "description").all?(&:blank?) &&
        attributes.fetch("rate", 0).to_d.zero? && attributes.fetch("amount", 0).to_d.zero?
    end

    def assign_number
      self.number = format("CN-%06d", id)
      update_column(:number, number)
    end

    def stamping?
      changes.except("updated_at").all? { |attribute, (from, _to)| STAMPED_ATTRIBUTES.include?(attribute) && from.nil? }
    end
end
