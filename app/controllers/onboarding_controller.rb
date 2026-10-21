class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :require_current_workspace

  STEPS = %w[workspace_type details balances].freeze
  WORKSPACE_TYPES = %w[personal business].freeze

  before_action :redirect_completed_user
  before_action :set_step

  def show
    redirect_to_required_step and return unless step_available?

    prepare_view
  end

  def update
    case @step
    when "workspace_type" then choose_workspace_type
    when "details" then save_details
    when "balances" then provision_workspace
    end
  end

  private
    def choose_workspace_type
      if WORKSPACE_TYPES.include?(params[:workspace_type])
        onboarding_data["workspace_type"] = params[:workspace_type]
        redirect_to onboarding_step_path(:details)
      else
        render_error("Choose a workspace type to continue.")
      end
    end

    def save_details
      details = {
        "workspace_name" => params[:workspace_name].to_s.strip,
        "currency_code" => params[:currency_code].to_s,
        "fiscal_year_start_month" => params.fetch(:fiscal_year_start_month, 1).to_i,
        "template" => params.fetch(:template, ChartCatalog.default_template(workspace_type)).to_s
      }

      if details["workspace_name"].blank?
        render_error("Enter a name for your workspace.", details)
      elsif !Currency.codes.include?(details["currency_code"])
        render_error("Choose a currency for your workspace.", details)
      elsif !(1..12).cover?(details["fiscal_year_start_month"])
        render_error("Choose the month your financial year starts.", details)
      elsif !ChartCatalog.templates_for(workspace_type).key?(details["template"])
        render_error("Choose a starting chart of accounts.", details)
      else
        onboarding_data.merge!(details)
        redirect_to onboarding_step_path(:balances)
      end
    end

    def provision_workspace
      onboarding_data["opening_balance_date"] = params[:opening_balance_date].presence || Date.current.iso8601
      onboarding_data["balances"] = balance_params
      opening_date = parse_date(onboarding_data["opening_balance_date"])
      balances = onboarding_data["balances"].transform_values { |amount| amount.blank? ? 0 : MoneyInput.to_kobo(amount) }

      if opening_date.nil? || opening_date > Date.current
        render_error("Choose a date that isn't in the future.")
      elsif (invalid = balances.key(nil))
        render_error("Enter the #{account_name(invalid)} balance as a positive number, like 1,250.00.")
      else
        workspace = Workspace.create_for_user!(
          user: Current.user,
          name: onboarding_data["workspace_name"],
          workspace_type: workspace_type,
          currency_code: onboarding_data["currency_code"],
          fiscal_year_start_month: onboarding_data["fiscal_year_start_month"],
          template: onboarding_data["template"],
          opening_balances: balances,
          opening_balance_date: opening_date
        )

        Current.session.update!(workspace: workspace)
        session.delete(:onboarding)
        redirect_to overview_path
      end
    rescue ActiveRecord::RecordInvalid => invalid
      render_error(invalid.record.errors.full_messages.to_sentence)
    end

    def balance_params
      keys = balance_accounts.map { |account| account[:key] }
      params.fetch(:balances, {}).permit(*keys).to_h.slice(*keys)
    end

    def balance_accounts
      ChartCatalog.accounts_for(workspace_type, template: onboarding_data["template"])
        .select { |account| AccountingEngine::Builders::OpeningBalance::ELIGIBLE_SUBTYPES.include?(account[:subtype]) }
    end

    def account_name(key)
      balance_accounts.find { |account| account[:key] == key }&.dig(:name)
    end

    def workspace_type
      onboarding_data.fetch("workspace_type")
    end

    def set_step
      @step = params[:step].to_s
      raise ActionController::RoutingError, "Not Found" unless STEPS.include?(@step)
    end

    def prepare_view(typed = {})
      @onboarding_data = onboarding_data.merge(typed)
      @steps = STEPS
      @balance_accounts = balance_accounts if @step == "balances"
    end

    def onboarding_data
      session[:onboarding] ||= {}
    end

    def step_available?
      STEPS.index(@step) <= STEPS.index(furthest_step)
    end

    def redirect_to_required_step
      redirect_to onboarding_step_path(furthest_step)
    end

    def furthest_step
      if onboarding_data["workspace_name"].present?
        "balances"
      elsif onboarding_data["workspace_type"].present?
        "details"
      else
        "workspace_type"
      end
    end

    def redirect_completed_user
      redirect_to overview_path if current_workspace
    end

    def render_error(message, typed = {})
      flash.now[:alert] = message
      prepare_view(typed)
      render :show, status: :unprocessable_content
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
end
