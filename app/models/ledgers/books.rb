module Ledgers
  module Books
    extend ActiveSupport::Concern

    def close_books!(through:, actor:)
      unless workspace.owned_by?(actor)
        errors.add(:base, "Only workspace owners can close the ledger")
        raise ActiveRecord::RecordInvalid, self
      end

      Ledger.transaction do
        lock!

        if closed_through.present? && through <= closed_through
          errors.add(:base, "Ledger is already closed through #{closed_through.iso8601}")
          raise ActiveRecord::RecordInvalid, self
        end

        update!(closed_through: through, closed_at: Time.current, closed_by: actor)
      end

      self
    end

    def reopen_books!(actor:)
      unless workspace.owned_by?(actor)
        errors.add(:base, "Only workspace owners can reopen the ledger")
        raise ActiveRecord::RecordInvalid, self
      end

      Ledger.transaction do
        lock!

        if closed_through.nil?
          errors.add(:base, "Ledger is already open")
          raise ActiveRecord::RecordInvalid, self
        end

        update!(closed_through: nil, closed_at: nil, closed_by_id: nil)
      end

      self
    end
  end
end
