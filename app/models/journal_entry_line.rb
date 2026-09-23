class JournalEntryLine < ApplicationRecord
  belongs_to :journal_entry, inverse_of: :journal_entry_lines
  belongs_to :account
  belongs_to :counterparty, polymorphic: true, optional: true

  validates :debit_kobo, :credit_kobo, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :exactly_one_side_is_positive
  validate :account_belongs_to_same_workspace
  validate :counterparty_belongs_to_same_workspace

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def debit
    return nil if debit_kobo.nil?

    BigDecimal(debit_kobo) / 100
  end

  def debit=(value)
    self.debit_kobo = value.blank? ? 0 : (BigDecimal(value.to_s) * 100).round
  end

  def credit
    return nil if credit_kobo.nil?

    BigDecimal(credit_kobo) / 100
  end

  def credit=(value)
    self.credit_kobo = value.blank? ? 0 : (BigDecimal(value.to_s) * 100).round
  end

  private

  def exactly_one_side_is_positive
    return if debit_kobo.nil? || credit_kobo.nil?
    return if debit_kobo.positive? ^ credit_kobo.positive?

    errors.add(:base, "must have either a debit or a credit, not both or neither")
  end

  def account_belongs_to_same_workspace
    return if account.blank? || journal_entry.blank? || journal_entry.workspace_id.blank?
    return if account.workspace_id == journal_entry.workspace_id

    errors.add(:account, "must belong to the same workspace as the entry")
  end

  def counterparty_belongs_to_same_workspace
    return if counterparty.blank? || journal_entry.blank? || journal_entry.workspace_id.blank?
    return unless counterparty.respond_to?(:workspace_id)
    return if counterparty.workspace_id == journal_entry.workspace_id

    errors.add(:counterparty, "must belong to the same workspace as the entry")
  end
end
