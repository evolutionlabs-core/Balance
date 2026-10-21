module Workspaces
  module Creation
    extend ActiveSupport::Concern

    class_methods do
      def create_for_user!(user:, name:, workspace_type:, currency_code:, fiscal_year_start_month: 1, template: nil,
        opening_balances: {}, opening_balance_date: Date.current, opening_balance_kobo: 0)
        Workspace.transaction do
          workspace = create!(
            name: name,
            workspace_type: workspace_type,
            currency_code: currency_code,
            fiscal_year_start_month: fiscal_year_start_month,
            onboarding_completed_at: Time.current
          )
          workspace.memberships.create!(user: user, role: :owner)
          workspace.provision_ledger!(template: template)
          balances = opening_balances.merge(opening_balance_kobo.positive? ? { "bank" => opening_balance_kobo } : {})
          workspace.post_opening_balances!(balances, on: opening_balance_date) if balances.values.any?(&:positive?)
          workspace
        end
      end
    end

    def post_opening_balances!(balances, on:)
      receipt = AccountingEngine.record(
        AccountingEngine::Builders::OpeningBalance,
        workspace: self,
        attributes: { balances: balances, effective_date: on },
        source_id: id
      )

      return if receipt.success?

      errors.add(:base, receipt.errors.map(&:to_s).to_sentence)
      raise ActiveRecord::RecordInvalid, self
    end
  end
end
