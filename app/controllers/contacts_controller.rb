class ContactsController < ApplicationController
  before_action :set_invoice, if: -> { params[:invoice_id].present? }
  before_action :set_contact, only: %i[edit update]

  def index
    @role = params[:role].presence_in(Contact::ROLE_NAMES)
    @contacts = current_workspace.contacts.includes(:contact_roles).ordered
    @contacts = @contacts.with_role(@role) if @role
  end

  def new
    role_names = Array(params[:role].presence_in(Contact::ROLE_NAMES))
    @contact = current_workspace.contacts.build(active: true, role_names: role_names)
  end

  def create
    @contact = current_workspace.contacts.build(contact_params)

    if @contact.save
      if @invoice
        @invoice.change_customer(@contact)
        render :update
      else
        redirect_out_of_frame contacts_path, notice: "Contact created."
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @contact.update(contact_params)
      if @invoice
        @invoice.change_customer(@contact)
        render :update
      else
        redirect_out_of_frame contacts_path, notice: "Contact updated."
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.find(params[:invoice_id])
    end

    def set_contact
      @contact = current_workspace.contacts.find(params[:id])
    end

    def contact_params
      params.expect(contact: [
        :name, :contact_kind, :email, :phone, :active,
        :address,
        role_names: []
      ])
    end
end
