require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(
      name: "Example Customer",
      customer_type: "business",
      email: "customer@example.com"
    )
    @service = @workspace.services.create!(name: "Consulting service", income_account: revenue_account)
  end

  test "calculates line amounts and invoice totals in minor units" do
    invoice = build_invoice(lines: [
      { description: "Consulting", quantity: 2, rate_minor: 15_000 },
      { description: "Support", quantity: 1.5, rate_minor: 10_000 }
    ])

    assert invoice.valid?, invoice.errors.full_messages.to_sentence
    assert_equal [ 30_000, 15_000 ], invoice.invoice_lines.map(&:amount_minor)
    assert_equal [ 0, 1 ], invoice.invoice_lines.map(&:position)
    assert_equal 45_000, invoice.subtotal_minor
    assert_equal 45_000, invoice.total_minor
  end

  test "recalculates client supplied totals and line amounts" do
    invoice = build_invoice(lines: [
      { description: "Consulting", quantity: 2, rate_minor: 15_000, amount_minor: 1 }
    ])
    invoice.subtotal_minor = 1
    invoice.total_minor = 1

    invoice.save!

    assert_equal 30_000, invoice.invoice_lines.first.amount_minor
    assert_equal 30_000, invoice.subtotal_minor
    assert_equal 30_000, invoice.total_minor
  end

  test "requires at least one submitted line" do
    invoice = build_invoice(lines: [])

    assert_not invoice.valid?
    assert_includes invoice.errors[:invoice_lines], "must include at least one item"
    assert_equal 0, invoice.subtotal_minor
    assert_equal 0, invoice.total_minor
  end

  test "ignores a blank placeholder when another line is complete" do
    invoice = @workspace.invoices.build(
      user: @user,
      customer: @customer,
      invoice_lines_attributes: {
        "0" => { service: @service, description: "Consulting", quantity: 2, rate: 20, amount: 40 },
        "1" => { service_id: "", description: "", quantity: 1, rate: 0, amount: 0 }
      }
    )

    assert invoice.valid?, invoice.errors.full_messages.to_sentence
    assert_equal 1, invoice.invoice_lines.size
  end

  test "requires a customer even for an incomplete draft" do
    invoice = build_invoice(customer: nil, lines: [ { description: "Draft line", quantity: nil, rate_minor: nil } ])
    invoice.issue_date = nil
    invoice.due_date = nil

    assert_not invoice.valid?
    assert_includes invoice.errors[:customer], "can't be blank"
    assert_equal 0, invoice.invoice_lines.first.amount_minor
  end

  test "allows free-form lines and restricts service mappings to the workspace" do
    other_workspace = workspaces(:bola_shop)
    other_income = other_workspace.accounts.create!(name: "Other Invoice Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    foreign_service = other_workspace.services.create!(name: "Foreign invoice service", income_account: other_income)

    missing = @workspace.invoices.build(user: @user, customer: @customer,
      invoice_lines_attributes: [ { description: "Work", quantity: 1, rate_minor: 100 } ])
    foreign = @workspace.invoices.build(user: @user, customer: @customer,
      invoice_lines_attributes: [ { service: foreign_service, description: "Work", quantity: 1, rate_minor: 100 } ])

    assert missing.valid?, missing.errors.full_messages.to_sentence
    assert_nil missing.invoice_lines.first.account
    assert_not foreign.valid?
    assert_includes foreign.invoice_lines.first.errors[:service], "must belong to the workspace"

    invoice = build_invoice
    invoice.save!
    original_account = invoice.invoice_lines.first.account
    replacement = @workspace.accounts.create!(name: "Replacement Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @service.update!(income_account: replacement)

    assert_equal original_account, invoice.reload.invoice_lines.first.account
  end

  test "assigns an invoice number on create" do
    invoice = build_invoice

    assert_nil invoice.invoice_number
    invoice.save!

    assert_equal format("INV-%06d", invoice.id), invoice.invoice_number
  end

  test "free-form invoice accounts are snapshotted and reviewed before posting" do
    @workspace.update!(default_sales_account: revenue_account)
    invoice = build_invoice(lines: [ { service: nil, description: "One-off work", quantity: 2, rate_minor: 500 } ])
    invoice.save!
    assert_equal revenue_account, invoice.invoice_lines.sole.account

    replacement = @workspace.accounts.create!(name: "New sales", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @workspace.update!(default_sales_account: replacement)
    invoice.update!(due_date: Date.current + 20)
    assert_equal revenue_account, invoice.reload.invoice_lines.sole.account

    result = invoice.post(receivable_account: receivable_account,
      line_accounts: [ { id: invoice.invoice_lines.sole.id, account_id: replacement.id } ])
    assert result.success?, result.errors.to_sentence
    assert_equal replacement, invoice.reload.invoice_lines.sole.account
    assert_equal [ [ receivable_account.id, 1000, 0 ], [ replacement.id, 0, 1000 ] ].sort,
      result.entry.journal_entry_lines.map { |line| [ line.account_id, line.debit_kobo, line.credit_kobo ] }.sort

    reversal = result.entry.reverse!
    assert_equal result.entry, reversal.reverses_journal_entry
    assert_equal result.entry.journal_entry_lines.map { |line| [ line.account_id, line.credit_kobo, line.debit_kobo ] }.sort,
      reversal.journal_entry_lines.map { |line| [ line.account_id, line.debit_kobo, line.credit_kobo ] }.sort
  end

  test "unmapped drafts cannot post and invalid review does not persist changes" do
    invoice = build_invoice(lines: [ { service: nil, description: "One-off work", quantity: 1, rate_minor: 500 } ])
    invoice.save!
    assert_no_difference("JournalEntry.count") do
      result = invoice.post(receivable_account: receivable_account)
      assert_not result.success?
      assert_includes result.errors.to_sentence, "income account"
    end

    foreign = Account.for_role!(workspaces(:bola_shop), :uncategorized_income)
    assert_no_difference("JournalEntry.count") do
      result = invoice.post(receivable_account: receivable_account,
        line_accounts: [ { id: invoice.invoice_lines.sole.id, account_id: foreign.id } ])
      assert_not result.success?
    end
    assert_nil invoice.reload.invoice_lines.sole.account
    assert invoice.draft?
  end

  test "posts a balanced receivable entry using line account snapshots" do
    invoice = build_invoice(lines: [
      { description: "Hosting", quantity: 12, rate_minor: 50_000 },
      { description: "Domain", quantity: 1, rate_minor: 150_000 }
    ])
    invoice.save!
    other_income = @workspace.accounts.create!(name: "Other Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    invoice.invoice_lines.first.update!(account: other_income)

    result = invoice.post(receivable_account: receivable_account)

    assert result.success?, result.errors.to_sentence
    assert invoice.reload.posted?
    entry = invoice.journal_entry
    assert_equal @workspace, entry.workspace
    assert_equal Date.current, entry.entry_date
    assert_equal "Invoice #{invoice.invoice_number}", entry.description
    debits = entry.journal_entry_lines.select { |line| line.debit_kobo.nonzero? }
    credits = entry.journal_entry_lines.select { |line| line.credit_kobo.nonzero? }
    assert_equal [ [ receivable_account.id, 750_000 ] ], debits.map { |line| [ line.account_id, line.debit_kobo ] }
    assert_equal [ @customer ], debits.map(&:counterparty)
    assert_equal [ [ other_income.id, 600_000 ], [ revenue_account.id, 150_000 ] ],
                 credits.map { |line| [ line.account_id, line.credit_kobo ] }
    assert_equal [ other_income, revenue_account ], invoice.reload.invoice_lines.map(&:account)
  end

  test "rejects posting twice" do
    invoice = build_invoice
    invoice.save!

    assert invoice.post(receivable_account: receivable_account).success?

    assert_no_difference("JournalEntry.count") do
      result = invoice.post(receivable_account: receivable_account)

      assert_not result.success?
    end
  end

  test "rejects posting accounts outside the workspace or of the wrong type" do
    invoice = build_invoice
    invoice.save!
    other_workspace = workspaces(:bola_shop)
    foreign = other_workspace.accounts.create!(name: "Foreign", base_type: "asset",
      account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    bank_account = @workspace.accounts.create!(name: "Not Receivable", base_type: "asset",
      account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    expense_account = @workspace.accounts.create!(name: "Materials", base_type: "expense",
      account_type: "Personal Outflows", detail_type: "Transportation")

    result = invoice.post(receivable_account: foreign)

    assert_not result.success?
    assert_includes result.errors.to_sentence, "receivable account must belong to the workspace"

    result = invoice.post(receivable_account: bank_account)

    assert_not result.success?
    assert_includes result.errors.to_sentence, "receivable account must be Accounts Receivable"

    invoice.invoice_lines.first.update_column(:account_id, expense_account.id)
    result = invoice.post(receivable_account: receivable_account)

    assert_not result.success?
    assert_includes result.errors.to_sentence, "every invoice line account must be workspace income"
    assert invoice.reload.draft?
    assert_nil invoice.journal_entry_id
  end

  test "locks lines once posted" do
    invoice = build_invoice
    invoice.save!
    invoice.post(receivable_account: receivable_account)
    line = invoice.reload.invoice_lines.first

    assert_not line.update(description: "Changed")
    assert_not line.destroy
    assert_not invoice.update(due_date: Date.current + 90)
    assert_not invoice.destroy
    assert_not invoice.invoice_lines.build(description: "Extra", quantity: 1, rate_minor: 100).save
    assert_equal "Consulting", line.reload.description
  end

  test "rejects customers belonging to another workspace" do
    customer = workspaces(:bola_shop).customers.create!(name: "Foreign customer", customer_type: "business", email: "foreign@example.com")
    invoice = build_invoice(customer: customer)
    assert_not invoice.valid?
    assert_includes invoice.errors[:customer], "must belong to the workspace"
  end

  private
    def receivable_account
      Account.for_role!(@workspace, :receivable)
    end

    def revenue_account
      @revenue_account ||= @workspace.accounts.create!(name: "Services Income", base_type: "income",
        account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    end

    def build_invoice(customer: @customer, user: @user, lines: nil)
      lines ||= [ { description: "Consulting", quantity: 2, rate_minor: 15_000 } ]

      @workspace.invoices.build(
        user: user,
        customer: customer,
        issue_date: Date.current,
        due_date: Date.current + 30.days,
        currency_code: "NGN",
        invoice_lines_attributes: lines.map { |line| { service: @service }.merge(line) }
      )
    end
end
