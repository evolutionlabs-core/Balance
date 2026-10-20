module BusinessWorkspace
  extend ActiveSupport::Concern

  included do
    before_action :require_business_workspace
  end

  private
    def require_business_workspace
      return if current_workspace&.business?

      redirect_to root_path, alert: "Bills and vendors are only available in business workspaces."
    end
end
