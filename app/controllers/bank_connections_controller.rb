class BankConnectionsController < ApplicationController
  include BankAccess

  def create
    self.bank_access_token = Beerus.exchange_public_token(params.expect(:public_token))

    head :created
  end
end
