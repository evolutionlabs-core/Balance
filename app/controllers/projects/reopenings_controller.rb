class Projects::ReopeningsController < Projects::ActionsController
  def create
    respond_with_transition(
      notice: "Estimate #{@estimate.number} moved back to draft.",
      alert: "Only declined estimates can be reopened."
    ) { @estimate.reopen! }
  end
end
