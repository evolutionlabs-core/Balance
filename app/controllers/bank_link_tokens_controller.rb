class BankLinkTokensController < ApplicationController
  include BankAccess

  def create
    link_token = Beerus.create_link_token(user_id: "workspace_#{current_workspace.id}", redirect_uri: redirect_uri)

    render json: { link_token: link_token }
  rescue Beerus::Error => error
    render_bank_link_error(error)
  end

  private
    def redirect_uri
      ENV["BEERUS_REDIRECT_URI"].presence || bank_transactions_url
    end
end
