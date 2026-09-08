class ContactsController < ApplicationController
  before_action :set_contact, only: %i[show edit update]

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
      redirect_out_of_frame contacts_path, notice: "Contact created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @history = ContactTransactionHistory.new(@contact)
  end

  def edit
  end

  def update
    if @contact.update(contact_params)
      redirect_out_of_frame return_path, notice: "Contact updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_contact
      @contact = current_workspace.contacts.includes(:contact_roles).find(params[:id])
    end

    def return_path
      url_from(params[:return_to]) || contacts_path
    end

    def contact_params
      params.expect(contact: [ :name, :contact_kind, :email, :phone, :active, role_names: [] ])
    end
end
