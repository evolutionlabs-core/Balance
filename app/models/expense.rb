class Expense < ApplicationRecord
  belongs_to :workspace
  belongs_to :payment_account, class_name: "Account"
  belongs_to :journal_entry, optional: true
  has_many :expense_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :expense

  accepts_nested_attributes_for :expense_lines, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: "draft", posted: "posted" }, validate: true

  validates :payment_date, presence: true
  validate :payment_date_is_not_in_the_future
  validate :payment_date_is_not_too_far_in_the_past
  validate :payment_account_belongs_to_workspace
  validate :payment_account_is_eligible
  validate :has_category_lines

  before_update { throw(:abort) if status_in_database == "posted" }
  before_destroy { throw(:abort) if posted? }
  before_validation :calculate_total_kobo

  def total_kobo
    super || calculated_total_kobo
  end

  def possible_duplicates
    workspace.expenses
      .where(payment_date: payment_date, total_kobo: total_kobo)
      .where.not(id: id)
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

  def journal_entry_draft
    workspace.journal_entries.build(
      entry_date: payment_date,
      description: description,
      journal_entry_lines_attributes: expense_lines.map do |line|
        { account: line.account, debit_kobo: line.amount_kobo, credit_kobo: 0 }
      end.push(account: payment_account, debit_kobo: 0, credit_kobo: total_kobo)
    )
  end

  def post
    Accounting::PostingService.call(source: self, entry_builder: -> {
      expense_lines.lock.load
      journal_entry_draft
    })
  end

  def record_posting!(entry)
    update!(journal_entry: entry, status: :posted)
  end

  private
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
      return if payment_account.workspace_id == workspace_id

      errors.add(:payment_account, "must belong to the workspace")
    end

    def payment_account_is_eligible
      return if payment_account.blank? || workspace.blank?
      return if workspace.payment_accounts.exists?(payment_account.id)

      errors.add(:payment_account, "must be an asset or credit-card account")
    end

    def has_category_lines
      return if expense_lines.reject(&:marked_for_destruction?).any?

      errors.add(:expense_lines, "must include at least one category")
    end
end
