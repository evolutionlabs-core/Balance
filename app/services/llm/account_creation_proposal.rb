class Llm::AccountCreationProposal
  BASE_TYPES = AccountSubtypes::SUBTYPES.keys.freeze

  attr_reader :data, :errors

  def self.from_tool(workspace:, reason:, accounts:)
    new(
      workspace: workspace,
      data: {
        "reason" => reason.to_s.strip,
        "accounts" => Array(accounts).map { |account| account.to_h.transform_keys(&:to_s).slice("name", "base_type", "subtype") }
      }
    )
  end

  def initialize(workspace:, data:)
    @workspace = workspace
    @data = data
    @errors = validate
  end

  def valid? = errors.empty?

  def invalid? = !valid?

  def create_accounts!
    raise ActiveRecord::RecordInvalid, rejected_record if invalid?

    Account.transaction do
      data["accounts"].map { |account| create_account!(account) }
    end
  end

  private

  def create_account!(account)
    ledger.accounts.create!(
      name: account["name"],
      base_type: account["base_type"],
      subtype: account["subtype"],
      code: next_code,
      created_by: "agent"
    )
  end

  def next_code
    code = 9900
    code += 10 while ledger.accounts.exists?(code: code.to_s)
    code.to_s
  end

  def rejected_record
    Account.new.tap do |record|
      errors.each { |message| record.errors.add(:base, message) }
    end
  end

  def validate
    messages = []
    messages << "Explain why the account is required" if data["reason"].blank?
    messages << "Propose at least one account" if data["accounts"].blank?
    names = data["accounts"].filter_map { |account| account["name"].presence&.downcase }
    messages << "Each proposed account must have a unique name" if names.uniq.size != names.size
    existing_names = ledger.accounts.where("LOWER(name) IN (?)", names).pluck(:name)
    messages << "These accounts already exist: #{existing_names.join(", ")}" if existing_names.any?
    data["accounts"].each do |account|
      name = account["name"].presence
      messages << "Account name can't be blank" if name.blank?
      next if name.blank?

      messages << "Account #{name.inspect} must have a valid base type" unless BASE_TYPES.include?(account["base_type"])
      messages << "Account #{name.inspect} must have a valid subtype" unless AccountSubtypes.valid?(account["base_type"], account["subtype"])
    end
    messages.uniq
  end

  def ledger
    @ledger ||= @workspace.ledger
  end
end
