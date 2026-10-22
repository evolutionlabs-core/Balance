class Expense < ApplicationRecord
  include Expenses::Posting

  belongs_to :workspace
  belongs_to :payment_account, class_name: "Account"
  has_many :expense_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :expense
  has_one :journal_entry, -> { where(source_type: "Expense", action: "create") }, foreign_key: "source_id", inverse_of: false
  has_one :void_entry, -> { where(source_type: "Expense", action: "void") }, class_name: "JournalEntry", foreign_key: "source_id", inverse_of: false

  accepts_nested_attributes_for :expense_lines, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: "draft", posted: "posted", voided: "voided" }, validate: true

  validates :payment_date, presence: true
  validate :payment_date_is_not_in_the_future
  validate :payment_date_is_not_too_far_in_the_past
  validate :payment_account_belongs_to_workspace
  validate :payment_account_is_eligible
  validate :has_category_lines

  before_update { throw(:abort) unless status_in_database == "draft" || voiding? }
  before_destroy { throw(:abort) unless draft? }
  before_validation :calculate_total_kobo

  def total_kobo
    super || calculated_total_kobo
  end

  def category_label
    lines = expense_lines.reject(&:marked_for_destruction?)
    lines.map { |line| line.account.name }.to_sentence
  end

  def description
    return memo if memo.present?

    lines = expense_lines.reject(&:marked_for_destruction?)
    lines.map(&:description).to_sentence
  end

  def mark_posted!
    update!(status: :posted)
  end

  def voidable?
    posted? && journal_entry.present?
  end

  private
    def voiding?
      status_in_database == "posted" && voided? && (changed - [ "updated_at" ]) == [ "status" ]
    end

    def calculate_total_kobo
      self.total_kobo = expense_lines.reject(&:marked_for_destruction?).sum { |line| line.amount_kobo || 0 }
    end

    def calculated_total_kobo
      expense_lines.reject(&:marked_for_destruction?).sum { |line| line.amount_kobo || 0 }
    end

    def payment_date_is_not_in_the_future
      return if payment_date.blank? || payment_date <= Date.current

      errors.add(:payment_date, "cannot be in the future")
    end

    def payment_date_is_not_too_far_in_the_past
      return if payment_date.blank? || payment_date >= 10.years.ago.to_date

      errors.add(:payment_date, "is too far in the past")
    end

    def payment_account_belongs_to_workspace
      return if payment_account.blank? || workspace.blank?
      return if payment_account.ledger.workspace_id == workspace_id

      errors.add(:payment_account, "must belong to the workspace")
    end

    def payment_account_is_eligible
      return if payment_account.blank? || workspace.blank?
      return if workspace.payment_accounts.exists?(payment_account.id)

      errors.add(:payment_account, "must be a cash or credit-card account")
    end

    def has_category_lines
      return if expense_lines.reject(&:marked_for_destruction?).any?

      errors.add(:expense_lines, "must include at least one category")
    end
end
