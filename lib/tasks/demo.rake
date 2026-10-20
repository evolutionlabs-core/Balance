namespace :demo do
  desc "Populate a demo business workspace through the accounting engine (development only)"
  task seed: :environment do
    abort "demo:seed only runs in development." unless Rails.env.development?

    DemoSeed.new.run
  end
end

class DemoSeed
  EMAIL = "demo@balance.test".freeze
  PASSWORD = "balance-demo-2026".freeze

  def run
    abort "#{EMAIL} already exists. Reset the database first to seed again." if User.exists?(email_address: EMAIL)

    ActiveRecord::Base.transaction do
      create_owner
      record_capital
      create_services_and_customers
      create_invoices
      create_bills
      create_expenses
    end

    puts "Seeded #{@workspace.name}: #{@ledger.journal_entries.count} journal entries, " \
         "#{@workspace.invoices.count} invoices, #{@workspace.bills.count} bills, #{@workspace.expenses.count} expenses."
    puts "Sign in as #{EMAIL} (password in lib/tasks/demo.rake)."
  end

  private
    def create_owner
      @user = User.create!(full_name: "Tolu Adeyemi", email_address: EMAIL, password: PASSWORD)
      @workspace = Workspace.create_for_user!(user: @user, name: "Lagos Creative Studio", workspace_type: "business", currency_code: "NGN")
      @workspace.update!(address: "12 Admiralty Way, Lekki Phase 1, Lagos")
      @ledger = @workspace.ledger
      @accounts = @ledger.accounts.index_by(&:key)
      @workspace.update!(default_sales_account: @accounts.fetch("sales"))
    end

    def record_capital
      post_entry(
        on: days_ago(120),
        description: "Owner capital introduced",
        lines: [ [ "bank", 6_000_000_00, 0 ], [ "owner_contributions", 0, 6_000_000_00 ] ]
      )
    end

    def create_services_and_customers
      sales = @accounts.fetch("sales")
      @services = {
        identity: @workspace.services.create!(name: "Brand identity", description: "Logo, palette and brand guidelines", income_account: sales, default_rate_minor: 450_000_00),
        website: @workspace.services.create!(name: "Website build", description: "Design and build of a marketing website", income_account: sales, default_rate_minor: 1_200_000_00),
        retainer: @workspace.services.create!(name: "Monthly retainer", description: "Ongoing design support", income_account: sales, default_rate_minor: 250_000_00)
      }

      @customers = [
        [ "Ngozi Balogun", "single", "ngozi.balogun@example.com", "7B Admiralty Way, Lekki Phase 1, Lagos" ],
        [ "Acme Trading Co.", "business", "accounts@acmetrading.example.com", "45 Broad Street, Lagos Island" ],
        [ "Zenith Foods Ltd", "business", "finance@zenithfoods.example.com", "3 Aba Road, Port Harcourt" ],
        [ "Kemi Okafor", "single", "kemi.okafor@example.com", "18 Allen Avenue, Ikeja" ]
      ].map do |name, type, email, address|
        @workspace.customers.create!(name: name, customer_type: type, email: email, address: address)
      end
    end

    def create_invoices
      ngozi, acme, zenith, kemi = @customers

      paid = issue_invoice(acme, :website, issued: days_ago(85), due: days_ago(55))
      record_receipt(paid, on: days_ago(50), amount: paid.balance_due_kobo)

      part_paid = issue_invoice(zenith, :identity, issued: days_ago(50), due: days_ago(20))
      record_receipt(part_paid, on: days_ago(15), amount: 200_000_00)

      issue_invoice(ngozi, :identity, issued: days_ago(130), due: days_ago(100))
      issue_invoice(acme, :retainer, issued: days_ago(70), due: days_ago(40), quantity: 2)
      issue_invoice(kemi, :retainer, issued: days_ago(8), due: days_ago(-22))

      voided = issue_invoice(kemi, :identity, issued: days_ago(30), due: Date.current)
      voided.void!

      @workspace.invoices.create!(
        user: @user, customer: ngozi, issue_date: Date.current, due_date: Date.current + 30,
        invoice_lines_attributes: [ invoice_line(:website) ]
      )
    end

    def create_bills
      landlord = @workspace.vendors.create!(name: "Lekki Office Spaces", email: "billing@lekkioffices.example.com", address: "Plot 5, Lekki Phase 1")
      power = @workspace.vendors.create!(name: "Eko Electricity", email: "billing@ekedc.example.com")
      printer = @workspace.vendors.create!(name: "Yaba Print House", email: "orders@yabaprint.example.com")

      rent = enter_bill(landlord, "Office rent, quarter 3", "rent", 900_000_00, dated: days_ago(80), due: days_ago(70))
      rent.record_payment!(payment_account_id: @accounts.fetch("bank").id, paid_on: days_ago(70), amount_kobo: rent.balance_due_kobo)

      enter_bill(power, "Electricity, September", "utilities", 85_000_00, dated: days_ago(25), due: days_ago(10))
      enter_bill(printer, "Brochure print run", "cost_of_goods_sold", 140_000_00, dated: days_ago(12), due: days_ago(-18))
      enter_bill(landlord, "Office rent, quarter 4", "rent", 900_000_00, dated: days_ago(4), due: days_ago(-26))
    end

    def create_expenses
      [
        [ 95, "bank", "marketing", "Instagram ads", 120_000_00 ],
        [ 88, "bank", "professional_fees", "Accountant's fee", 75_000_00 ],
        [ 60, "bank", "payroll", "Design assistant salary, August", 350_000_00 ],
        [ 55, "credit_card", "other_expense", "Figma and Adobe subscriptions", 48_000_00 ],
        [ 30, "bank", "payroll", "Design assistant salary, September", 350_000_00 ],
        [ 22, "bank", "marketing", "Lagos Design Week booth", 180_000_00 ],
        [ 9, "credit_card", "other_expense", "Team lunch with client", 32_500_00 ],
        [ 2, "bank", "payroll", "Design assistant salary, October", 350_000_00 ]
      ].each do |days, paid_from, category, description, amount|
        expense = @workspace.expenses.build(payment_date: days_ago(days), payment_account: @accounts.fetch(paid_from), memo: description)
        expense.expense_lines.build(account: @accounts.fetch(category), description: description, amount_kobo: amount, position: 0)
        raise "Expense rejected: #{expense.errors.full_messages.to_sentence}" unless expense.record_entry!
      end
    end

    def issue_invoice(customer, service, issued:, due:, quantity: 1)
      invoice = @workspace.invoices.create!(
        user: @user, customer: customer, issue_date: issued, due_date: due,
        invoice_lines_attributes: [ invoice_line(service, quantity: quantity) ]
      )
      raise "Invoice rejected: #{invoice.errors.full_messages.to_sentence}" unless invoice.issue!

      invoice
    end

    def invoice_line(service, quantity: 1)
      record = @services.fetch(service)
      { service_id: record.id, description: record.description, quantity: quantity, rate: record.default_rate_minor / 100 }
    end

    def record_receipt(invoice, on:, amount:)
      recorded = invoice.record_payment!(deposit_account_id: @accounts.fetch("bank").id, received_on: on, amount_kobo: amount)
      raise "Payment rejected: #{invoice.errors.full_messages.to_sentence}" unless recorded
    end

    def enter_bill(vendor, description, account_key, amount_kobo, dated:, due:)
      bill = @workspace.bills.create!(
        user: @user, vendor: vendor, bill_date: dated, due_date: due,
        bill_lines_attributes: [ { account_id: @accounts.fetch(account_key).id, description: description, amount: format("%.2f", amount_kobo / 100.0) } ]
      )
      raise "Bill rejected: #{bill.errors.full_messages.to_sentence}" unless bill.issue!

      bill
    end

    def post_entry(on:, description:, lines:)
      receipt = AccountingEngine.record(
        AccountingEngine::Builders::Entry,
        workspace: @workspace,
        attributes: {
          effective_date: on,
          lines: lines.map { |key, debit, credit| { account_id: @accounts.fetch(key).id, debit: debit, credit: credit } }
        },
        source_id: nil,
        description: description
      )
      raise "Entry rejected: #{receipt.errors.join(", ")}" unless receipt.success?
    end

    def days_ago(days)
      Date.current - days
    end
end
