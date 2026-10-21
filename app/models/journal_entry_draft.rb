class JournalEntryDraft < ApplicationRecord
  LINE_KEYS = %w[account_id debit credit].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :posted_entry, class_name: "JournalEntry", optional: true

  scope :unposted, -> { where(posted_entry_id: nil) }

  before_update { throw(:abort) if posted_entry_id_in_database }
  before_destroy { throw(:abort) if posted? }

  def self.from_form(attributes)
    new.tap { |draft| draft.assign_form(attributes) }
  end

  def assign_form(attributes)
    self.effective_date = attributes[:effective_date].presence
    self.description = attributes[:description]
    self.lines = attributes[:lines]
  end

  def lines=(raw)
    rows = raw.respond_to?(:values) ? raw.values : Array(raw)
    super(rows.map { |row| row.to_h.stringify_keys }
      .reject { |row| row["_destroy"] == "1" }
      .map { |row| row.slice(*LINE_KEYS).transform_values(&:to_s) }
      .reject { |row| row.values.all?(&:blank?) })
  end

  def posted?
    posted_entry_id?
  end

  def entry_form
    form = JournalEntries::ManualEntry.new(workspace: workspace, effective_date: effective_date, description: description, lines: lines)
    (2 - form.lines.size).times { form.build_line }
    form
  end

  def total_kobo
    lines.sum { |line| MoneyInput.to_kobo(line["debit"].presence || "0") || 0 }
  end

  def post!
    form = entry_form

    if form.record!(source_type: "JournalEntryDraft", source_id: id)
      update!(posted_entry: form.entry)
      true
    else
      form.errors.each { |error| errors.add(:base, error.full_message) }
      false
    end
  end
end
