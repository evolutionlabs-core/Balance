class Accounting::PostingService
  Result = Data.define(:entry, :errors, :proof) do
    def success? = errors.empty?
  end

  def self.call(entry: nil, source: nil, entry_builder: nil, allocation_invoice: nil, engine: Accounting::Engine)
    new(entry, source: source, entry_builder: entry_builder, allocation_invoice: allocation_invoice, engine: engine).call
  end

  def initialize(entry, source:, entry_builder:, allocation_invoice:, engine:)
    @entry = entry
    @source = source
    @entry_builder = entry_builder
    @allocation_invoice = allocation_invoice
    @engine = engine
  end

  def call
    engine_result = nil

    JournalEntry.transaction do
      source&.lock!
      @entry = entry_builder.call if entry_builder

      if source&.posted?
        source.errors.add(:base, "has already been posted")
        raise ActiveRecord::Rollback
      end

      # Serialize approvals that target the same original entry.
      entry.reverses_journal_entry&.lock!

      engine_result = engine.check(entry.journal_entry_lines)
      unless engine_result.ok?
        entry.valid?
        engine_result.errors.each do |message|
          entry.errors.add(:base, message) unless entry.errors[:base].include?(message)
        end
        raise ActiveRecord::Rollback
      end

      entry.save!
      Accounting::ReceivableAllocator.call(entry, preferred_invoice: allocation_invoice)
      source.record_posting!(entry) if source
    end

    result(engine_result&.proof)
  rescue ActiveRecord::RecordInvalid
    result(engine_result&.proof)
  end

  private

  attr_reader :entry, :source, :entry_builder, :allocation_invoice, :engine

  def result(proof)
    errors = entry.errors.full_messages
    errors += source.errors.full_messages if source
    Result.new(entry, errors.uniq.freeze, proof)
  end
end
