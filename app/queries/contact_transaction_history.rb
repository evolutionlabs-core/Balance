class ContactTransactionHistory
  Row = Data.define(:record, :date, :description, :amount_kobo, :account, :status)

  def initialize(contact)
    @contact = contact
  end

  def rows
    @rows ||= sources.flatten.sort_by { |row| [ row.date, row.record.id ] }.reverse
  end

  def any?
    rows.any?
  end

  def posted_total_kobo
    rows.select { |row| row.status == "posted" }.sum(&:amount_kobo)
  end

  private
    attr_reader :contact

    def sources
      [ expense_rows ]
    end

    def expense_rows
      contact.paid_expenses
        .includes(:payment_account, :expense_lines)
        .map do |expense|
          Row.new(
            record: expense,
            date: expense.payment_date,
            description: expense.description,
            amount_kobo: expense.total_kobo,
            account: expense.payment_account,
            status: expense.status
          )
        end
    end
end
