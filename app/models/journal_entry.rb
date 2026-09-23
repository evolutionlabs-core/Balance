class JournalEntry < ApplicationRecord
  belongs_to :workspace
  belongs_to :reverses_journal_entry, class_name: "JournalEntry", optional: true
  has_many :journal_entry_lines, dependent: :destroy, inverse_of: :journal_entry
  has_many :receivable_applications, dependent: :restrict_with_error
  has_one :expense, dependent: :restrict_with_error
  has_one :invoice, dependent: :restrict_with_error

  accepts_nested_attributes_for :journal_entry_lines, allow_destroy: true, reject_if: :all_blank

  validates :description, presence: true
  validates :entry_date, presence: true
  validate :complies_with_accounting_principles
  validate :cannot_reverse_a_reversal
  validate :reversal_stays_in_workspace
  validate :reversal_is_unique
  validate :reversal_is_exact_mirror
  validate :entry_date_not_in_the_future
  validate :entry_date_not_too_far_in_the_past

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def reverse!
    self.class.transaction do
      reversal = workspace.journal_entries.build(
        entry_date: Date.current,
        description: "Reversal of journal entry #{id}",
        reverses_journal_entry: self,
        journal_entry_lines_attributes: journal_entry_lines.map do |line|
          {
            account_id: line.account_id,
            debit: line.credit,
            credit: line.debit,
            counterparty: line.counterparty
          }
        end
      )
      result = Accounting::PostingService.call(entry: reversal)
      raise ActiveRecord::RecordInvalid, reversal unless result.success?

      result.entry
    end
  end

  private

  def cannot_reverse_a_reversal
    return if reverses_journal_entry.blank? || reverses_journal_entry.reverses_journal_entry_id.blank?

    errors.add(:reverses_journal_entry, "cannot reverse an entry that is itself a reversal")
  end

  def reversal_stays_in_workspace
    return if reverses_journal_entry.blank? || workspace.blank?
    return if reverses_journal_entry.workspace_id == workspace_id

    errors.add(:reverses_journal_entry, "must belong to the same workspace as the entry")
  end

  def reversal_is_unique
    return if reverses_journal_entry.blank? || workspace.blank?
    return unless workspace.journal_entries.where(reverses_journal_entry_id: reverses_journal_entry_id).where.not(id: id).exists?

    errors.add(:reverses_journal_entry, "has already been reversed")
  end

  def reversal_is_exact_mirror
    return if reverses_journal_entry.blank?

    Accounting::Engine.reversal_errors(
      original_lines: reverses_journal_entry.journal_entry_lines,
      reversal_lines: journal_entry_lines
    ).each { |message| errors.add(:base, message) }
  end

  def complies_with_accounting_principles
    result = Accounting::Engine.check(journal_entry_lines)
    result.errors.each { |message| errors.add(:base, message) }
  end

  def entry_date_not_in_the_future
    return if entry_date.blank?

    errors.add(:entry_date, "cannot be in the future") if entry_date > Date.current
  end

  def entry_date_not_too_far_in_the_past
    return if entry_date.blank?

    errors.add(:entry_date, "is too far in the past") if entry_date < 10.years.ago.to_date
  end
end
