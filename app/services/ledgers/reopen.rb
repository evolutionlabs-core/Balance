module Ledgers
  class Reopen
    Result = Data.define(:ledger, :error) do
      def ok? = error.nil?
    end

    def self.call(ledger:, actor:)
      new(ledger: ledger, actor: actor).call
    end

    def initialize(ledger:, actor:)
      @ledger = ledger
      @actor = actor
    end

    def call
      unless ledger.workspace.owned_by?(actor)
        return Result.new(nil, "Only workspace owners can reopen the ledger")
      end

      Ledger.transaction do
        ledger.lock!

        if ledger.closed_through.nil?
          return Result.new(nil, "Ledger is already open")
        end

        ledger.update!(closed_through: nil, closed_at: nil, closed_by_id: nil)
        Result.new(ledger, nil)
      end
    end

    private
      attr_reader :ledger, :actor
  end
end
