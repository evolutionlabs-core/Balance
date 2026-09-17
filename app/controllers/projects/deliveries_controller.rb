class Projects::DeliveriesController < Projects::ActionsController
  def create
    respond_with_transition(
      notice: "Estimate #{@estimate.number} sent.",
      alert: "Only draft estimates can be sent."
    ) { @estimate.send_to_client! }
  end
end
