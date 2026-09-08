class Contact < ApplicationRecord
  ROLE_NAMES = %w[vendor customer].freeze
  CONTACT_KINDS = %w[individual business].freeze

  belongs_to :workspace
  has_many :contact_roles, dependent: :destroy, autosave: true
  has_many :paid_expenses, class_name: "Expense", foreign_key: :payee_contact_id, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error

  validates :name, :email, :contact_kind, presence: true
  validates :contact_kind, inclusion: { in: CONTACT_KINDS }
  validate :has_role

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :with_role, ->(role) { joins(:contact_roles).where(contact_roles: { role: role }).distinct }

  def role_names
    contact_roles.reject(&:marked_for_destruction?).map(&:role)
  end

  def role_names=(roles)
    selected_roles = Array(roles).compact_blank & ROLE_NAMES

    contact_roles.each do |contact_role|
      contact_role.mark_for_destruction unless selected_roles.include?(contact_role.role)
    end

    existing_roles = contact_roles.reject(&:marked_for_destruction?).map(&:role)
    (selected_roles - existing_roles).each { |role| contact_roles.build(role: role) }
  end

  private
    def has_role
      return if contact_roles.reject(&:marked_for_destruction?).any?

      errors.add(:roles, "must include at least one role")
    end
end
