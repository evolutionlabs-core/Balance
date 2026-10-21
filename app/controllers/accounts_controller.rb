class AccountsController < ApplicationController
  before_action :set_ledger, only: %i[new create edit update]
  before_action :set_account, only: %i[edit update]

  def index
    @archived = params[:archived] == "1"
    @accounts = current_workspace.accounts.public_send(@archived ? :archived : :active).order(:code)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      @accounts = @accounts.where("accounts.name ILIKE :term OR accounts.code ILIKE :term", term: term)
    end
    @balances = current_workspace.ledgers.first ? AccountingEngine::Balances.new(current_workspace.ledger).by_account : {}
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
