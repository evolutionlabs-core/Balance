class Llm::JournalEntryProposal
  attr_reader :data, :errors

  def self.from_tool(workspace:, description:, entry_date:, lines:)
    new(
      workspace: workspace,
      data: {
        "description" => description,
        "entry_date" => entry_date || Date.current.to_s,
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
        "entry_date" => params[:entry_date],
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
      "amount_kobo" => amount_to_kobo(line[:amount_naira]),
      "counterparty_name" => line[:counterparty_name]
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
      raise ArgumentError, "JournalEntryProposal needs a Workspace, got #{workspace.class} (was a Chat or workspace wired in place of a workspace?)"
    end

    @workspace = workspace
    @data = data
    @counterparty_errors = []
    resolve_counterparties
    entry.valid?
    @errors = (entry.errors.full_messages + @counterparty_errors).uniq
  end

  def valid?
    errors.empty?
  end

  def invalid?
    !valid?
  end

  def build_journal_entry!
    result = Accounting::PostingService.call(entry: entry)
    raise ActiveRecord::RecordInvalid, entry unless result.success?

    result.entry
  end

  def entry
    @entry ||= begin
      built = @workspace.journal_entries.build(
        description: data["description"],
        entry_date: parse_date(data["entry_date"]),
        reverses_journal_entry_id: data["reverses_journal_entry_id"]
      )
      original_lines = if data["reverses_journal_entry_id"].present?
        @workspace.journal_entries.find_by(id: data["reverses_journal_entry_id"])&.journal_entry_lines
      end

      data["lines"].each do |line|
        attributes = {}
        if line["side"] == "debit"
          attributes[:debit_kobo] = line["amount_kobo"]
        elsif line["side"] == "credit"
          attributes[:credit_kobo] = line["amount_kobo"]
        else
          attributes[:debit_kobo] = attributes[:credit_kobo] = line["amount_kobo"]
        end

        if line["account_id"].present?
          attributes[:account] = @workspace.accounts.find_by(id: line["account_id"])
        end
        if original_lines
          attributes[:counterparty] = original_lines.find { |original| original.id == line["source_line_id"] }&.counterparty
        elsif line["counterparty_id"].present?
          attributes[:counterparty] = @workspace.customers.find_by(id: line["counterparty_id"])
        end

        built.journal_entry_lines.build(attributes)
      end

      built
    end
  end

  private
    def resolve_counterparties
      return if data["reverses_journal_entry_id"].present?

      data.fetch("lines", []).each do |line|
        name = line["counterparty_name"].presence
        account = @workspace.accounts.find_by(id: line["account_id"])
        next unless line["side"] == "credit" && account&.role == "receivable"

        unless name
          @counterparty_errors << "Accounts Receivable credit must name an existing customer"
          next
        end

        matches = @workspace.customers.where("LOWER(name) = ?", name.downcase).limit(2).to_a
        if matches.one?
          line["counterparty_id"] = matches.first.id
        elsif matches.empty?
          @counterparty_errors << "Customer #{name.inspect} does not exist in this workspace"
        else
          @counterparty_errors << "Customer #{name.inspect} is ambiguous in this workspace"
        end
      end
    end

    def parse_date(value)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
end
