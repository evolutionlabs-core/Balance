module BankAccess
  extend ActiveSupport::Concern

  private
    def bank_access_token
      session.fetch(:bank_access_tokens, {})[current_workspace.id.to_s]
    end

    def bank_access_token=(token)
      session[:bank_access_tokens] = session.fetch(:bank_access_tokens, {}).merge(current_workspace.id.to_s => token)
    end

    def render_bank_link_error(error)
      Rails.logger.error("Bank linking failed: #{error.message}")

      render json: { error: "Couldn't start bank linking. Try again in a moment." }, status: :bad_gateway
    end
end
