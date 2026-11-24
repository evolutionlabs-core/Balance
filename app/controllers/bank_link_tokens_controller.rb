class BankLinkTokensController < ApplicationController
  def create
    link_token = Beerus.create_link_token(user_id: "workspace_#{current_workspace.id}", redirect_uri: bank_transactions_url)

    render json: { link_token: link_token }
  end
end
