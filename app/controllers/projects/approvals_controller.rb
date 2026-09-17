class Projects::ApprovalsController < Projects::ActionsController
  def create
    respond_with_transition(
      notice: "Estimate #{@estimate.number} approved.",
      alert: "Only sent estimates can be approved."
    ) { @estimate.approve! }
  end
end
