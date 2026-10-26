class CreditNotesController < ApplicationController
  before_action :set_credit_note, only: :show
  before_action :set_form_choices, only: %i[new create]

  def index
    @credit_notes = current_workspace.credit_notes.includes(:customer, :applications).ordered
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data Pdf::CreditNote.new(@credit_note).render, filename: "credit-note-#{@credit_note.number}.pdf",
          type: "application/pdf", disposition: "attachment"
      end
    end
  end

  def new
    if params[:invoice_id]
      @credit_note = CreditNote.from_invoice(current_workspace.invoices.where(status: %w[sent paid]).find(params[:invoice_id]), user: Current.user)
    else
      @credit_note = current_workspace.credit_notes.build(user: Current.user, issued_on: Date.current, currency_code: current_workspace.currency_code)
      @credit_note.lines.build(quantity: 1)
    end
  end

  def create
    @credit_note = current_workspace.credit_notes.build(credit_note_params)
    @credit_note.user = Current.user

    if @credit_note.issue!
      redirect_to credit_note_path(@credit_note)
    else
      @credit_note.lines.build(quantity: 1) if @credit_note.lines.empty?
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_credit_note
      @credit_note = current_workspace.credit_notes.includes(:customer, :lines, applications: :invoice).find(params[:id])
    end

    def set_form_choices
      @services = current_workspace.services.ordered.to_a
      @customers = current_workspace.customers.active.order(:name)
    end

    def credit_note_params
      params.expect(credit_note: [
        :customer_id, :invoice_id, :issued_on, :notes,
        lines_attributes: [ [ :service_id, :description, :quantity, :rate, :amount ] ]
      ])
    end
end
