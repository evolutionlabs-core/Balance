module AccountingEngine
  module PeriodState
    class AccountStatus
      def self.call(command)
        inactive_ids = Account.where(id: account_ids(command), active: false).pluck(:id)

        [].tap do |errors|
          command.lines.each_with_index do |line, index|
            account = line.account
            errors << Error.new(:account, "Line #{index + 1}: account #{account.name} is inactive") if inactive_ids.include?(account.id)
          end
        end
      end

      class << self
        private
          def account_ids(command)
            command.lines.map { |line| line.account.id }.uniq
          end
      end
    end
  end
end
