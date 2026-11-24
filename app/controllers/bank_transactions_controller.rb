class BankTransactionsController < ApplicationController
  include BankAccess

  def index
    @linked = bank_access_token.present?

    if @linked
      @transactions = Beerus.posted_transactions(bank_access_token)
    end
  rescue Beerus::Error
    flash.now[:alert] = "Your bank isn't responding. Try again in a moment."
  end
end
