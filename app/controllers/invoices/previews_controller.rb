class Invoices::PreviewsController < ApplicationController
  include InvoiceParams

  def create
    @invoice = params[:invoice_id] ? current_workspace.invoices.where(status: "draft").find(params[:invoice_id]) : new_invoice
    @invoice.assign_attributes(invoice_params)
    @invoice.valid?
  end

  private
    def new_invoice
      current_workspace.invoices.build(user: Current.user, currency_code: current_workspace.currency_code, issue_date: Date.current)
    end
end
