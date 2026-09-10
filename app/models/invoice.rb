class Invoice < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :contact, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  validates :contact, presence: true, unless: -> { validation_context == :editing }

  enum :status, { draft: "draft" }, validate: true

  before_validation :populate_party_details, on: :create
  before_validation :calculate_totals

  # Negative form indexes identify saved rows; omitted saved rows are removed on save.
  def invoice_lines_attributes=(attributes)
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

  def use_contact_details
    self.bill_to_name = contact&.name
    self.bill_to_email = contact&.email
    self.bill_to_address = contact&.address
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

  def change_customer(customer)
    self.contact = customer
    use_contact_details
    save!
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

    if contact
      self.bill_to_name = contact.name if bill_to_name.nil?
      self.bill_to_email = contact.email if bill_to_email.nil?
      self.bill_to_address = contact.address if bill_to_address.nil?
    end
  end

  private
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
