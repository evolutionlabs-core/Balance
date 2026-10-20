class Proposal < ApplicationRecord
  TYPES = %w[account_creation entry reversal_confirmation].freeze
  STATUSES = %w[proposed confirming confirmed dismissed superseded].freeze

  belongs_to :workspace
  belongs_to :llm_chat, class_name: "Llm::Chat"
  belongs_to :llm_message, class_name: "Llm::Message", optional: true
  belongs_to :journal_entry, optional: true

  validates :proposal_type, presence: true, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :data, presence: true

  scope :proposed, -> { where(status: "proposed") }
  scope :by_type, ->(type) { where(proposal_type: type) }

  def entry_proposal?
    proposal_type == "entry"
  end

  def account_creation_proposal?
    proposal_type == "account_creation"
  end

  def reversal_proposal?
    entry_proposal? && data["reverses_journal_entry_id"].present?
  end

  def reversal_confirmation?
    proposal_type == "reversal_confirmation"
  end

  def pending? = status == "proposed"

  def confirmed? = status == "confirmed"

  def description = data&.dig("description")
  def effective_date = data&.dig("effective_date")
  def shape = data&.dig("shape")
  def needs_attention = data&.dig("needs_attention")
  def lines = data&.dig("lines") || []
  def accounts = data&.dig("accounts") || []

  def total_debit_kobo
    lines.sum { |line| line["side"] == "debit" ? line["amount_kobo"].to_i : 0 }
  end

  def total_credit_kobo
    lines.sum { |line| line["side"] == "credit" ? line["amount_kobo"].to_i : 0 }
  end

  def complete?
    return false if effective_date.blank?
    return false if lines.size < 2
    return false if lines.any? { |line| line["account_id"].blank? || line["amount_kobo"].to_i <= 0 }

    total_debit_kobo == total_credit_kobo
  end

  def confirm!(draft:)
    @confirm_errors = nil
    with_lock do
      return [ "Confirm the selected entry before reviewing its reversal proposal." ] unless entry_proposal?
      return [] unless pending?
      return draft.errors if draft.invalid?
      return [] unless transition_to_confirming?

      receipt = draft.post!(source_id: id)
      unless receipt.success?
        @confirm_errors = receipt.errors.map(&:to_s)
        raise ActiveRecord::Rollback
      end

      update!(status: "confirmed", journal_entry: receipt.entry)
      nil
    end
    @confirm_errors
  end

  def confirm_accounts!(draft:)
    with_lock do
      return [] unless pending?
      return draft.errors if draft.invalid?
      return [] unless transition_to_confirming?

      created = draft.create_accounts!
      update!(
        status: "confirmed",
        data: data.merge(
          "created_accounts" => created.map { |account| { "id" => account.id, "name" => account.name } }
        )
      )
      nil
    end
  end

  def dismiss!
    update!(status: "dismissed")
  end

  def supersede!
    update!(status: "superseded")
  end

  private

  def transition_to_confirming?
    Proposal.where(id: id, status: "proposed")
      .update_all(status: "confirming", updated_at: Time.current) == 1
  end
end
