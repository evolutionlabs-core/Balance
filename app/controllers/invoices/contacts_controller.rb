class Invoices::ContactsController < ApplicationController
  before_action :set_invoice
  before_action :set_contact, only: %i[edit update]

  def index
    @customers = current_workspace.contacts.active.with_role("customer").ordered
    if params[:query].present?
      @customers = @customers.where("name ILIKE ?", "%#{Contact.sanitize_sql_like(params[:query])}%")
    end
  end

  def new
    @contact = current_workspace.contacts.build(active: true, role_names: %w[customer])
  end

  def create
    @contact = current_workspace.contacts.build(contact_params)

    if @contact.save
      apply_contact
      render :refresh
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def show
    @contact = current_workspace.contacts.active.with_role("customer").find(params[:id])
    @invoice.contact = @contact
    @invoice.use_contact_details
    render :refresh
  end

  def update
    if @contact.update(contact_params)
      apply_contact
      render :refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = if params[:invoice_id].present?
        current_workspace.invoices.find(params[:invoice_id])
      else
        current_workspace.invoices.build
      end
    end

    def set_contact
      @contact = current_workspace.contacts.find(params[:id])
    end

    def apply_contact
      if @invoice.persisted?
        @invoice.change_customer(@contact)
      else
        @invoice.contact = @contact
        @invoice.use_contact_details
      end
    end

    def contact_params
      params.expect(contact: [ :name, :contact_kind, :email, :phone, :address, role_names: [] ])
    end
end
