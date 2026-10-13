class Llm::EntryProposal
  attr_reader :data, :errors

  def self.from_tool(workspace:, description:, effective_date:, lines:)
    new(
      workspace: workspace,
      data: {
        "description" => description,
        "effective_date" => effective_date,
        "amount_source" => "user_provided",
        "lines" => lines.map { |line| line_data(line, form: false) }
      }
    )
  end

  def self.from_form(workspace:, params:)
    new(
      workspace: workspace,
      data: {
        "description" => params[:description],
        "effective_date" => params[:effective_date],
        "amount_source" => "user_edited",
        "reverses_ledger_entry_id" => params[:reverses_ledger_entry_id].presence&.to_i,
        "lines" => (params[:lines] || {}).values.map { |line| line_data(line, form: true) }
      }
    )
  end

  def self.line_data(line, form:)
    line = line.to_h.transform_keys(&:to_sym) unless form

    {
      "ledger_account_id" => line[:ledger_account_id].presence&.to_i,
      "side" => line[:side],
      "amount_kobo" => amount_to_kobo(line[:amount_naira])
    }
  end

  def self.amount_to_kobo(value)
    raw = value.to_s.gsub(/[^\d.]/, "")
    return nil if raw.blank?

    (BigDecimal(raw) * 100).round
  rescue ArgumentError
    nil
  end

  def initialize(workspace:, data:)
    unless workspace.is_a?(Workspace)
      raise ArgumentError, "EntryProposal needs a Workspace, got #{workspace.class} (was a Chat or workspace wired in place of a workspace?)"
    end

    @workspace = workspace
    @data = data
    @errors = validate
  end

  def valid? = errors.empty?

  def invalid? = !valid?

  def reversal? = data["reverses_ledger_entry_id"].present?

  def post!(source_id:)
    command = Engine::Adapters::Entry.call(
      workspace: @workspace,
      attributes: {
        action: reversal? ? "reverse" : "create",
        effective_date: parsed_date,
        lines: command_lines
      },
      source_id: source_id,
      description: data["description"]
    )
    Engine.post(command)
  rescue ActiveRecord::RecordNotFound => error
    Engine::Receipt.new(nil, [ error.message ].freeze, :reject, [].freeze)
  rescue ActiveRecord::RecordNotUnique
    Engine::Receipt.new(nil, [ already_recorded_message ].freeze, :reject, [].freeze)
  end

  private
    def validate
      messages = []
      messages << "Description can't be blank" if data["description"].blank?
      messages << "Effective date can't be blank" if data["effective_date"].blank?
      messages << "Effective date is not a valid date" if data["effective_date"].present? && parsed_date.nil?
      messages << "An entry requires at least two lines" if data.fetch("lines", []).size < 2

      data.fetch("lines", []).each_with_index do |line, index|
        account = line["ledger_account_id"] && ledger.ledger_accounts.find_by(id: line["ledger_account_id"].to_i)
        messages << "Line #{index + 1}: choose an account in this workspace" if account.nil?
        messages << "Line #{index + 1}: amount must be positive" unless line["amount_kobo"].to_i.positive?
      end
      messages << balance_message unless balanced?

      return messages unless reversal?

      original = ledger.ledger_entries.find_by(id: data["reverses_ledger_entry_id"])
      messages << "Original entry not found in this workspace" if original.nil?
      if original
        messages << "Only entries recorded from chat can be reversed" if original.source_type != "Entry"
        messages << "Entry ##{original.id} has already been reversed" if reversed?(original.id)
        messages << "This entry is itself a reversal" if reversal_entry?(original.id)
      end
      messages.uniq
    end

    def reversed?(entry_id)
      confirmed_reversals.where("data ->> 'reverses_ledger_entry_id' = ?", entry_id.to_s).exists?
    end

    def reversal_entry?(entry_id)
      confirmed_reversals.where("data -> 'reverses_ledger_entry_id' IS NOT NULL").find_by(ledger_entry_id: entry_id).present?
    end

    def confirmed_reversals
      Proposal.where(proposal_type: "entry", status: "confirmed")
    end

    def command_lines
      data.fetch("lines", []).map do |line|
        if line["side"] == "debit"
          { ledger_account_id: line["ledger_account_id"], debit: line["amount_kobo"].to_i, credit: 0 }
        else
          { ledger_account_id: line["ledger_account_id"], debit: 0, credit: line["amount_kobo"].to_i }
        end
      end
    end

    def balanced?
      debit_total = data.fetch("lines", []).select { |line| line["side"] == "debit" }.sum { |line| line["amount_kobo"].to_i }
      credit_total = data.fetch("lines", []).select { |line| line["side"] == "credit" }.sum { |line| line["amount_kobo"].to_i }

      debit_total == credit_total
    end

    def balance_message
      debit_total = data.fetch("lines", []).select { |line| line["side"] == "debit" }.sum { |line| line["amount_kobo"].to_i }
      credit_total = data.fetch("lines", []).select { |line| line["side"] == "credit" }.sum { |line| line["amount_kobo"].to_i }

      "Total debits (#{format_kobo(debit_total)}) must equal total credits (#{format_kobo(credit_total)})"
    end

    def parsed_date
      value = data["effective_date"]
      return value if value.is_a?(Date)

      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def format_kobo(amount_kobo)
      format("%d.%02d", amount_kobo / 100, amount_kobo % 100)
    end

    def ledger
      @ledger ||= @workspace.ledgers.first ||
        @workspace.provision_ledger!(template: @workspace.ledger_template)
    end

    def already_recorded_message
      reversal? ? "This reversal has already been recorded." : "This entry has already been recorded."
    end
end
