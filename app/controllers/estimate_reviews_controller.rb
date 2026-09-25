class EstimateReviewsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_current_workspace
  layout "client_review"
  before_action :protect_review
  before_action :set_estimate

  def show
  end

  def create
    @estimate.record_client_decision(params[:token], params[:decision])
    render :confirmation
  rescue Estimate::InvalidClientReview
    render :unavailable, status: :gone
  end

  private
    def protect_review
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "same-origin"
      response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
    end

    def set_estimate
      @estimate = Estimate.find_by_token_for(:client_review, params[:token])
      render :unavailable, status: :gone unless @estimate&.sent?
    end
end
