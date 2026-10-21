module JournalEntries
  class Reversal
    include ActiveModel::Model
    include AccountingEngine::Postable

    validates :effective_date, presence: true
    validate :effective_date_is_valid

    attr_accessor :entry, :effective_date, :description
    attr_reader :reversal

    def record!
      return false unless valid?

      @reversal = JournalEntry.transaction do
        reverse_in_ledger!(entry, on: parsed_date, source_type: "JournalEntry", source_id: entry.id,
          description: description.presence || "Reversal of entry ##{entry.number}")
      end

      reversal.present?
    end

    private
      def workspace
        entry.ledger.workspace
      end

      def effective_date_is_valid
        if effective_date.blank?
          nil
        elsif parsed_date.nil?
          errors.add(:effective_date, "is not a valid date")
        elsif parsed_date < entry.effective_date
          errors.add(:effective_date, "can't be before the original entry (#{entry.effective_date.to_fs(:medium)})")
        end
      end

      def parsed_date
        effective_date.is_a?(Date) ? effective_date : Date.iso8601(effective_date.to_s)
      rescue Date::Error
        nil
      end
  end
end
