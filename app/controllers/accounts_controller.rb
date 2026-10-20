class AccountsController < ApplicationController
  before_action :set_ledger, only: %i[new create edit update]
  before_action :set_account, only: %i[edit update]

  def index
    @accounts = Account.where(ledger: current_workspace.ledgers).order(:code)
  end

  def new
    @account = @ledger.accounts.build
  end

  def create
    @account = @ledger.accounts.build(account_params)

    if @account.save
      redirect_out_of_frame accounts_path, notice: "Account created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account updated."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  private
    def set_ledger
      @ledger = current_workspace.ledgers.sole
    end

    def set_account
      @account = @ledger.accounts.where.not(created_by: "system").find(params[:id])
    end

    def account_params
      params.expect(account: [ :code, :name, :base_type, :subtype, :description ])
    end
end
