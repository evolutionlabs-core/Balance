class BankSyncsController < ApplicationController
  include BankAccess

  def create
    Beerus.refresh(bank_access_token)

    redirect_to bank_transactions_path
  rescue Beerus::Error
    redirect_to bank_transactions_path, alert: "Couldn't sync. Try again in a moment."
  end
end
