class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :require_current_workspace

  STEPS = %w[workspace_type details].freeze

  before_action :redirect_completed_user
  before_action :set_step

  def show
    redirect_to_required_step and return unless step_available?

    prepare_view
  end

  def update
    case @step
    when "workspace_type" then choose_workspace_type
    when "details" then provision_workspace
    end
  end

  private

  def choose_workspace_type
    if params[:workspace_type] == "personal"
      onboarding_data["workspace_type"] = "personal"
      redirect_to onboarding_step_path(:details)
    else
      render_error("Business workspaces are coming soon.")
    end
  end

  def provision_workspace
    name = params[:workspace_name].to_s.strip
    return render_error("Enter a name for your personal workspace.") if name.blank?
    onboarding_data["workspace_name"] = name
    onboarding_data["opening_balance_naira"] = params[:opening_balance_naira].presence || "0"

    opening_balance_kobo = parse_opening_balance(onboarding_data["opening_balance_naira"])
    return render_error("Opening balance must be zero or more.") unless opening_balance_kobo

    workspace = Workspaces::Provisioner.call(
      user: Current.user,
      name: name,
      workspace_type: onboarding_data.fetch("workspace_type"),
      currency_code: "NGN",
      opening_balance_kobo: opening_balance_kobo
    )

    Current.session.update!(workspace: workspace)
    session.delete(:onboarding)
    redirect_to overview_path, notice: "Your personal workspace is ready."
  rescue ActiveRecord::RecordInvalid => invalid
    render_error(invalid.record.errors.full_messages.to_sentence)
  end

  def set_step
    @step = params[:step].to_s
    raise ActionController::RoutingError, "Not Found" unless STEPS.include?(@step)
  end

  def prepare_view
    @onboarding_data = onboarding_data
    @steps = STEPS
  end

  def onboarding_data
    session[:onboarding] ||= {}
  end

  def step_available?
    return true if @step == "workspace_type"

    onboarding_data["workspace_type"].present?
  end

  def redirect_to_required_step
    required = onboarding_data["workspace_type"].present? ? :details : :workspace_type
    redirect_to onboarding_step_path(required)
  end

  def redirect_completed_user
    redirect_to overview_path if current_workspace
  end

  def render_error(message)
    flash.now[:alert] = message
    prepare_view
    render :show, status: :unprocessable_content
  end

  def parse_opening_balance(value)
    amount = BigDecimal(value.to_s)
    return if amount.negative?

    (amount * 100).round
  rescue ArgumentError
    nil
  end
end
