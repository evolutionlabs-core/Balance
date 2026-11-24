module BankAccess
  extend ActiveSupport::Concern

  private
    def bank_access_token
      session.fetch(:bank_access_tokens, {})[current_workspace.id.to_s]
    end

    def bank_access_token=(token)
      session[:bank_access_tokens] = session.fetch(:bank_access_tokens, {}).merge(current_workspace.id.to_s => token)
    end
end
