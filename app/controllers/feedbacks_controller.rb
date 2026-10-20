class FeedbacksController < ApplicationController
  before_action :ensure_enabled

  def new
    @report = FeedbackReport.new(page: request.referer)
  end

  def create
    @report = FeedbackReport.new(report_params)
    @report.reporter = Current.user
    @report.browser = request.user_agent

    if @report.submit
      render :sent
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def ensure_enabled
      head :not_found unless FeedbackReport.enabled?
    end

    def report_params
      params.expect(feedback_report: %i[kind description page])
    end
end
