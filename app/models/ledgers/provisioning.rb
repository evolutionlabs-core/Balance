module Ledgers
  module Provisioning
    extend ActiveSupport::Concern

    def provision_ledger!(template: nil)
      raise ArgumentError, "Workspace already has a ledger" if ledgers.exists?

      Ledger.transaction do
        ledger = Ledger.create!(workspace: self, name: "General", currency_code: currency_code)

        ChartCatalog.accounts_for(workspace_type, template: template).each do |account|
          ledger.accounts.create!(**account, created_by: "system")
        end

        update!(
          default_deposit_account: ledger.accounts.find_by!(key: "bank"),
          default_sales_account: ledger.accounts.find_by(key: business? ? "sales" : "other_income")
        )
        ledger
      end
    end
  end
end
