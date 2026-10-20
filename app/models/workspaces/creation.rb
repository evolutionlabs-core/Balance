module Workspaces
  module Creation
    extend ActiveSupport::Concern

    class_methods do
      def create_for_user!(user:, name:, workspace_type:, currency_code:, opening_balance_kobo: 0)
        Workspace.transaction do
          workspace = create!(
            name: name,
            workspace_type: workspace_type,
            currency_code: currency_code,
            onboarding_completed_at: Time.current
          )
          workspace.memberships.create!(user: user, role: :owner)
          workspace.provision_ledger!
          workspace.post_opening_balance!(opening_balance_kobo) if opening_balance_kobo.positive?
          workspace
        end
      end
    end

    def post_opening_balance!(amount_kobo)
      receipt = AccountingEngine.record(
        AccountingEngine::Builders::OpeningBalance,
        workspace: self,
        attributes: { opening_balance_kobo: amount_kobo },
        source_id: id
      )

      return if receipt.success?

      errors.add(:base, receipt.errors.map(&:to_s).to_sentence)
      raise ActiveRecord::RecordInvalid, self
    end
  end
end
