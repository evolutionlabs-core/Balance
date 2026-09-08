module LedgerTestHelper
  def create_payment_account(workspace, name: "Checking")
    workspace.accounts.create!(
      name: name,
      base_type: "asset",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )
  end

  def create_expense_account(workspace, name: "Fuel")
    workspace.accounts.create!(
      name: name,
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Transportation"
    )
  end

  def create_vendor(workspace, name: "Fuel Station")
    workspace.contacts.create!(
      name: name,
      contact_kind: "business",
      email: "#{name.parameterize}@example.com",
      role_names: %w[vendor]
    )
  end

  def create_expense(workspace, payee_contact:, payment_account:, category:, payment_date: Date.current, amount_kobo: 4_000_000, memo: "Fuel")
    workspace.expenses.create!(
      payment_date: payment_date,
      payment_account: payment_account,
      payee_contact: payee_contact,
      memo: memo,
      expense_lines_attributes: [
        { account: category, description: "Fuel", amount_kobo: amount_kobo, position: 0 }
      ]
    )
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include LedgerTestHelper
end
