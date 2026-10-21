require "csv"

class ReportCsv
  FORMULA_PREFIX = /\A[=+\-@\t\r]/

  def self.statement(statement)
    CSV.generate do |csv|
      csv << [ "Code", "Line", *statement.columns.map(&:label) ]
      statement.lines.each do |line|
        csv << [ line.code, text(line.label), *(line.amounts || Array.new(statement.columns.size)).map { |amount| figure(amount) } ]
      end
    end
  end

  def self.trial_balance(trial_balance)
    CSV.generate do |csv|
      csv << [ "Code", "Account", "Debit", "Credit" ]
      trial_balance.rows.each do |row|
        csv << [ row.account.code, text(row.account.name), figure(row.debit), figure(row.credit) ]
      end
      csv << [ nil, "Total", figure(trial_balance.total_debit), figure(trial_balance.total_credit) ]
    end
  end

  def self.general_ledger(ledger)
    CSV.generate do |csv|
      csv << [ "Date", "Entry", "Description", "Counterparty", "Debit", "Credit", "Balance" ]
      csv << [ ledger.from.iso8601, nil, "Opening balance", nil, nil, nil, figure(ledger.opening_balance) ]
      ledger.lines.each do |line|
        csv << [ line.entry.effective_date.iso8601, line.entry.number, text(line.entry.description), text(line.counterparty&.name),
          figure(line.debit), figure(line.credit), figure(line.balance) ]
      end
      csv << [ ledger.to.iso8601, nil, "Closing balance", nil, nil, nil, figure(ledger.closing_balance) ]
    end
  end

  def self.figure(minor)
    format("%.2f", BigDecimal(minor) / 100) unless minor.nil?
  end
  private_class_method :figure

  def self.text(value)
    value.to_s.match?(FORMULA_PREFIX) ? "'#{value}" : value
  end
  private_class_method :text
end
