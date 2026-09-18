class Projects::DeclinesController < Projects::ActionsController
  def create
    respond_with_transition(
      notice: "Estimate #{@estimate.number} declined.",
      alert: "Only sent estimates can be declined."
    ) { @estimate.decline! }
  end
end
