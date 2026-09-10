class InvoiceForms::CustomersController < ApplicationController
  def edit
    @invoice = current_workspace.invoices.build
    @customers = current_workspace.contacts.active.with_role("customer").ordered
    if params[:query].present?
      @customers = @customers.where("name ILIKE ?", "%#{Contact.sanitize_sql_like(params[:query])}%")
    end
  end

  def show
    customer = current_workspace.contacts.active.with_role("customer").find(params[:contact_id])
    @invoice = current_workspace.invoices.build(contact: customer)
    @invoice.use_contact_details
  end
end
