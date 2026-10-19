module Ledgers
  module Provisioning
    extend ActiveSupport::Concern

    def provision_ledger!
      raise ArgumentError, "Workspace already has a ledger" if ledgers.exists?

      Ledger.transaction do
        ledger = Ledger.create!(workspace: self, name: "General", currency_code: currency_code)

        ChartCatalog.accounts_for(workspace_type).each do |account|
          ledger.accounts.create!(**account, created_by: "system")
        end

        ledger
      end
    end
  end
end
