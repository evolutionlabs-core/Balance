class Invoice < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :contact, optional: true
  has_many :invoice_lines, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: "draft" }, validate: true

  before_validation :populate_party_details, on: :create
  before_validation :calculate_totals

  def use_contact_details
    self.bill_to_name = contact&.name
    self.bill_to_email = contact&.email
    self.bill_to_address = contact&.address
  end

  def add_line
    with_lock do
      line = invoice_lines.build
      save!
      line
    end
  end

  def change_line(id, attributes)
    revise(invoice_lines_attributes: [ attributes.merge(id: id) ])
  end

  def revise(attributes)
    with_lock { update(attributes) }
  end

  def remove_line(id)
    with_lock do
      line = invoice_lines.find(id)
      line.destroy!
      invoice_lines.reset
      save!
      line
    end
  end

  def change_customer(customer)
    with_lock do
      self.contact = customer
      use_contact_details
      save!
    end
  end

  def refresh_business_details
    with_lock do
      self.business_name = workspace.name
      self.business_email = user.email_address
      self.business_address = workspace.address
      save!
    end
  end

  private
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
