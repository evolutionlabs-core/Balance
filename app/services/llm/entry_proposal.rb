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
        "reverses_journal_entry_id" => params[:reverses_journal_entry_id].presence&.to_i,
        "lines" => (params[:lines] || {}).values.map { |line| line_data(line, form: true) }
      }
    )
  end

  def self.line_data(line, form:)
    line = line.to_h.transform_keys(&:to_sym) unless form

    {
      "account_id" => line[:account_id].presence&.to_i,
      "side" => line[:side],
      "amount_kobo" => amount_to_kobo(line[:amount_naira])
    }
  end

  def self.amount_to_kobo(value)
    MoneyInput.to_kobo(value)
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

  def reversal? = data["reverses_journal_entry_id"].present?

  def post!(source_id:)
    if reversal?
      AccountingEngine.reverse(original_entry, on: parsed_date, source_type: "Entry", source_id: source_id,
        description: data["description"])
    else
      AccountingEngine.record(
        AccountingEngine::Builders::Entry,
        workspace: @workspace,
        attributes: { effective_date: parsed_date, lines: command_lines },
        source_id: source_id,
        description: data["description"]
      )
    end
  end

  private
    def validate
      messages = []
      messages << "Description can't be blank" if data["description"].blank?
      messages << "Effective date can't be blank" if data["effective_date"].blank?
      messages << "Effective date is not a valid date" if data["effective_date"].present? && parsed_date.nil?
      messages << "An entry requires at least two lines" if data.fetch("lines", []).size < 2

      data.fetch("lines", []).each_with_index do |line, index|
        account = line["account_id"] && ledger.accounts.find_by(id: line["account_id"].to_i)
        messages << "Line #{index + 1}: choose an account in this workspace" if account.nil?
        if account&.control_counterparty && !reversal?
          messages << "Line #{index + 1}: #{account.name} is a control account; record it through #{AccountingEngine::Validation::CounterpartyCheck::SUBLEDGERS.fetch(account.control_counterparty)}"
        end
        messages << "Line #{index + 1}: amount must be positive" unless line["amount_kobo"].to_i.positive?
      end
      messages << balance_message unless balanced?

      return messages unless reversal?

      if original_entry.nil?
        messages << "Original entry not found in this workspace"
      else
        messages << "Only entries recorded from chat can be reversed" if original_entry.source_type != "Entry"
        messages << "Entry ##{original_entry.number} has already been reversed" if original_entry.reversed?
        messages << "This entry is itself a reversal" if original_entry.reverses_entry_id?
      end
      messages.uniq
    end

    def original_entry
      @original_entry ||= ledger.journal_entries.find_by(id: data["reverses_journal_entry_id"])
    end

    def command_lines
      data.fetch("lines", []).map do |line|
        if line["side"] == "debit"
          { account_id: line["account_id"], debit: line["amount_kobo"].to_i, credit: 0 }
        else
          { account_id: line["account_id"], debit: 0, credit: line["amount_kobo"].to_i }
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
      @ledger ||= @workspace.ledger
    end
end
