class BillsController < ApplicationController
  include BusinessWorkspace

  before_action :set_bill, only: %i[show edit update]
  before_action :ensure_draft, only: %i[edit update]
  before_action :set_vendors, only: %i[new create edit update]

  def index
    @pagy, @bills = pagy(current_workspace.bills.includes(:vendor, :payments).order(created_at: :desc, id: :desc))
  end

  def new
    @bill = current_workspace.bills.build(
      bill_date: Date.current,
      currency_code: current_workspace.currency_code,
      vendor_id: params[:vendor_id]
    )
    @bill.bill_lines.build(position: 0)
  end

  def create
    @bill = current_workspace.bills.build(bill_params)
    @bill.user = Current.user

    if @bill.save
      redirect_to bill_path(@bill), notice: "Bill draft saved."
    else
      @bill.bill_lines.build(position: 0) if @bill.bill_lines.empty?
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  def edit
  end

  def update
    if @bill.update(bill_params)
      redirect_to bill_path(@bill), notice: "Bill draft saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_bill
      @bill = current_workspace.bills.includes(:vendor, :payments, bill_lines: :account).find(params[:id])
    end

    def ensure_draft
      return if @bill.draft?

      redirect_to bill_path(@bill), alert: "Only draft bills can be changed."
    end

    def set_vendors
      @vendors = current_workspace.vendors.active.ordered
    end

    def bill_params
      params.expect(bill: [
        :vendor_id, :bill_number, :bill_date, :due_date, :notes,
        bill_lines_attributes: [ [ :id, :account_id, :description, :amount, :position, :_destroy ] ]
      ])
    end
end
