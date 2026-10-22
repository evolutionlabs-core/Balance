module WorkspaceCurrency
  extend ActiveSupport::Concern

  included do
    before_validation :adopt_workspace_currency, on: :create
    validate :currency_matches_workspace
  end

  private
    def adopt_workspace_currency
      self.currency_code = workspace.currency_code if workspace
    end

    def currency_matches_workspace
      return if workspace.nil? || currency_code == workspace.currency_code

      errors.add(:currency_code, "must be the workspace currency (#{workspace.currency_code})")
    end
end
