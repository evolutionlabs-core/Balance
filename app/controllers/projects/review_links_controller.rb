class Projects::ReviewLinksController < Projects::ActionsController
  def create
    @estimate.prepare_client_review
    redirect_to project_estimate_path(@estimate), notice: "Review link ready. Copy it below and share it with your client."
  rescue Estimate::InvalidClientReview
    redirect_to project_estimate_path(@estimate), alert: "Only draft or sent estimates can be shared."
  end
end
