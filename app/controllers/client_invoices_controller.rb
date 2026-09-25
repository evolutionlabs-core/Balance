class ClientInvoicesController < ApplicationController
  allow_unauthenticated_access

  layout "client_invoice"

  before_action :set_invoice
  before_action :set_private_response_headers

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data Pdf::Invoice.new(@invoice).render, filename: "invoice-#{@invoice.invoice_number}.pdf",
          type: "application/pdf", disposition: "attachment"
      end
    end
  end

  private
    def set_invoice
      @invoice = Invoice.find_by_token_for(:client_view, params[:token])
      head :not_found unless @invoice&.posted?
    end

    def set_private_response_headers
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
end
