class Invoices::CustomersController < ApplicationController
  include InvoiceScoped

  def edit
    @customers = current_workspace.contacts.active.with_role("customer").ordered
    if params[:query].present?
      @customers = @customers.where("name ILIKE ?", "%#{Contact.sanitize_sql_like(params[:query])}%")
    end
  end

  def update
    customer = current_workspace.contacts.active.with_role("customer").find(params[:contact_id])
    @invoice.change_customer(customer)
  end
end
