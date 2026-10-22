class EntryTemplate < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :workspace_id, case_sensitive: false }
  validate :has_two_lines

  scope :ordered, -> { order(:name) }

  def self.from_entry(entry, user:, name:)
    new(
      workspace: entry.ledger.workspace,
      user: user,
      name: name.to_s.strip,
      description: entry.description,
      tags: entry.tags,
      lines: entry.journal_entry_lines.map do |line|
        { "account_id" => line.account_id.to_s, "debit" => amount(line.debit), "credit" => amount(line.credit) }
      end
    )
  end

  def self.amount(minor)
    minor.positive? ? format("%.2f", BigDecimal(minor) / 100) : ""
  end
  private_class_method :amount

  def draft(effective_date: Date.current)
    workspace.journal_entry_drafts.build(effective_date: effective_date, description: description, tags: tags, lines: lines)
  end

  private
    def has_two_lines
      errors.add(:base, "A template needs at least two lines") if lines.size < 2
    end
end
