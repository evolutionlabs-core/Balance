class Estimate < ApplicationRecord
  include AASM

  STATUSES = %w[draft sent approved declined].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :customer
  belongs_to :project, optional: true
  has_many :line_items, class_name: "EstimateLineItem", dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  def line_items_attributes=(attributes)
    drop_missing_lines(attributes) if saved_rows_submitted?(attributes)
    super(restore_line_ids(attributes))
  end

  validates :status, inclusion: { in: STATUSES }
  validates :currency_code, inclusion: { in: %w[NGN] }
  validate :customer_belongs_to_workspace
  validate :project_belongs_to_workspace
  validate :project_matches_customer

  before_validation :populate_party_details, on: :create
  before_validation :calculate_totals

  scope :ordered, -> { order(id: :desc) }

  def number
    format("EST-%06d", id || 0)
  end

  aasm column: :status do
    state :draft, initial: true
    state :sent, :approved, :declined

    event :send_to_client do
      transitions from: :draft, to: :sent
    end

    event :approve do
      transitions from: :sent, to: :approved
    end

    event :decline do
      transitions from: :sent, to: :declined
    end

    event :reopen do
      transitions from: :declined, to: :draft
    end
  end

  def use_customer_details
    self.bill_to_name = customer&.name
    self.bill_to_email = customer&.email
    self.bill_to_address = customer&.address
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
      return if customer.blank? || workspace.blank?
      return if customer.workspace_id == workspace_id

      errors.add(:customer, "must belong to the workspace")
    end

    def project_belongs_to_workspace
      return if project.blank? || workspace.blank?
      return if project.workspace_id == workspace_id

      errors.add(:project, "must belong to the workspace")
    end

    def project_matches_customer
      return if project.blank? || customer.blank?
      return if project.customer_id == customer_id

      errors.add(:project, "must belong to the same customer as the estimate")
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
      line_items.reject(&:marked_for_destruction?)
    end

    def saved_rows_submitted?(attributes)
      attributes.is_a?(Hash) && attributes.keys.any? { |key| key.to_s.start_with?("-") }
    end

    def drop_missing_lines(attributes)
      retained_ids = attributes.keys.filter_map do |key|
        key.to_s.delete_prefix("-").to_i if key.to_s.start_with?("-")
      end
      line_items.each do |line|
        line.mark_for_destruction unless retained_ids.include?(line.id)
      end
    end

    def restore_line_ids(attributes)
      return attributes unless saved_rows_submitted?(attributes)

      attributes.transform_keys(&:to_s).transform_values(&:to_h).each do |key, values|
        values["id"] = key.delete_prefix("-") if key.start_with?("-")
      end
    end
end
