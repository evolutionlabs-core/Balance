module InvoiceScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_invoice
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.find(params[:invoice_id])
    end
end
