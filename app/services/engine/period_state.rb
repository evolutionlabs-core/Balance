class Engine::PeriodState
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
    Result.new(ledger_errors.freeze)
  end

  private
    attr_reader :command

    # Account status and accounting periods have no schema yet. Only the
    # ledger's own status is enforced, so an unenforced check is never
    # reported as a passing one.
    def ledger_errors
      if command.ledger.active?
        []
      else
        [ "Ledger #{command.ledger.name} is #{command.ledger.status}" ]
      end
    end
end
