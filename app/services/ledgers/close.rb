module Ledgers
  class Close
    Result = Data.define(:ledger, :error) do
      def ok? = error.nil?
    end

    def self.call(ledger:, through:, actor:)
      new(ledger: ledger, through: through, actor: actor).call
    end

    def initialize(ledger:, through:, actor:)
      @ledger = ledger
      @through = through
      @actor = actor
    end

    def call
      unless ledger.workspace.owned_by?(actor)
        return Result.new(nil, "Only workspace owners can close the ledger")
      end

      Ledger.transaction do
        ledger.lock!

        if ledger.closed_through.present? && through <= ledger.closed_through
          return Result.new(nil, "Ledger is already closed through #{ledger.closed_through.iso8601}")
        end

        ledger.update!(closed_through: through, closed_at: Time.current, closed_by: actor)
        Result.new(ledger, nil)
      end
    end

    private
      attr_reader :ledger, :through, :actor
  end
end
