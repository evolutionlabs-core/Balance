class AccountsController < ApplicationController
  def index
    @ledger_accounts = LedgerAccount.where(ledger: current_workspace.ledgers).order(:code)
  end
end
