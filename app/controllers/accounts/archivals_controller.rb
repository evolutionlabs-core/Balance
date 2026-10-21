class Accounts::ArchivalsController < ApplicationController
  before_action :set_account

  def create
    if @account.archive
      redirect_to accounts_path
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  def destroy
    @account.restore
    redirect_to accounts_path(archived: "1")
  end

  private
    def set_account
      @account = current_workspace.accounts.find(params[:account_id])
    end
end
