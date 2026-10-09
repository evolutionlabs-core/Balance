class Engine::Validation
  Result = Data.define(:errors) do
    def ok? = errors.empty?
  end

  def self.call(command)
    new(command).call
  end

  def initialize(command)
    @command = command
  end

  def call
    Result.new(errors.freeze)
  end

  private
    attr_reader :command

    # Collected rather than raised so a caller sees every problem at once.
    def errors
      structure_errors + existence_errors + match_errors + amount_errors
    end

    def structure_errors
      if command.lines.size < 2
        [ "An entry requires at least two lines" ]
      else
        []
      end
    end

    def existence_errors
      foreign = command.lines.reject { |line| line.ledger_account&.ledger_id == command.ledger.id }
      if foreign.empty?
        []
      else
        [ "Every line must reference an account in ledger #{command.ledger.name}" ]
      end
    end

    def match_errors
      debits = command.lines.sum { |line| line.debit.to_d }
      credits = command.lines.sum { |line| line.credit.to_d }

      if debits == credits
        []
      else
        [ "Total debits (#{debits}) must equal total credits (#{credits})" ]
      end
    end

    def amount_errors
      invalid = command.lines.reject { |line| one_sided?(line) }
      if invalid.empty?
        []
      else
        [ "Each line must have either a positive debit or a positive credit" ]
      end
    end

    def one_sided?(line)
      debit = line.debit.to_d
      credit = line.credit.to_d

      (debit.positive? && credit.zero?) || (credit.positive? && debit.zero?)
    end
end
