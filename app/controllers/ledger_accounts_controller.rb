class LedgerAccountsController < ApplicationController
  before_action :set_ledger, only: %i[new create edit update]
  before_action :set_ledger_account, only: %i[edit update]

  def index
    @ledger_accounts = LedgerAccount.where(ledger: current_workspace.ledgers).order(:code)
  end

  def new
    @ledger_account = @ledger.ledger_accounts.build
  end

  def create
    @ledger_account = @ledger.ledger_accounts.build(ledger_account_params)

    if @ledger_account.save
      redirect_out_of_frame ledger_accounts_path, notice: "Account created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @ledger_account.update(ledger_account_params)
      redirect_to ledger_accounts_path, notice: "Account updated."
    else
      redirect_to ledger_accounts_path, alert: @ledger_account.errors.full_messages.to_sentence
    end
  end

  private
    def set_ledger
      @ledger = current_workspace.ledgers.sole
    end

    def set_ledger_account
      @ledger_account = @ledger.ledger_accounts.where.not(created_by: "system").find(params[:id])
    end

    def ledger_account_params
      params.expect(ledger_account: [ :code, :name, :base_type, :subtype, :description ])
    end
end
