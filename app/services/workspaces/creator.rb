class Workspaces::Creator
  def self.call(...)
    new(...).call
  end

  def initialize(user:, name:, workspace_type:, currency_code:, opening_balance_kobo: 0)
    @user = user
    @name = name
    @workspace_type = workspace_type
    @currency_code = currency_code
    @opening_balance_kobo = opening_balance_kobo
  end

  def call
    Workspace.transaction do
      workspace = Workspace.create!(
        name: @name,
        workspace_type: @workspace_type,
        currency_code: @currency_code,
        onboarding_completed_at: Time.current
      )
      workspace.memberships.create!(user: @user, role: :owner)
      Ledgers::Provisioner.call(workspace: workspace, template: workspace.ledger_template)
      post_opening_balance!(workspace) if @opening_balance_kobo.positive?
      workspace
    end
  end

  private
    attr_reader :user, :name, :workspace_type, :currency_code, :opening_balance_kobo

    def post_opening_balance!(workspace)
      receipt = Engine.post(
        Engine::Adapters::OpeningBalance.call(
          workspace: workspace,
          attributes: { opening_balance_kobo: opening_balance_kobo },
          source_id: workspace.id
        )
      )

      return if receipt.success? && receipt.verdict == :allow

      workspace.errors.add(:base, receipt.errors.map(&:to_s).to_sentence)
      raise ActiveRecord::RecordInvalid, workspace
    end
end
