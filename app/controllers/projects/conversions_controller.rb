class Projects::ConversionsController < Projects::ActionsController
  def create
    invoice = @estimate.build_invoice(user: Current.user)

    ActiveRecord::Base.transaction do
      @estimate.convert_to_invoice!
      invoice.save!
    end

    redirect_to invoice_path(invoice), notice: "Invoice #{invoice.invoice_number} created from #{@estimate.number}."
  rescue AASM::InvalidTransition
    redirect_to project_estimate_path(@estimate), alert: "Only approved estimates can be converted."
  end
end
