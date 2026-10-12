module Engine
  module PeriodState
    class AccountStatus
      def self.call(command)
        inactive_ids = LedgerAccount.where(id: account_ids(command), active: false).pluck(:id)

        [].tap do |errors|
          command.lines.each_with_index do |line, index|
            account = line.ledger_account
            errors << Error.new(:account, "Line #{index + 1}: account #{account.name} is inactive") if inactive_ids.include?(account.id)
          end
        end
      end

      class << self
        private
          def account_ids(command)
            command.lines.map { |line| line.ledger_account.id }.uniq
          end
      end
    end
  end
end
