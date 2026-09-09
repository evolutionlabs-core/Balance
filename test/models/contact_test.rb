require "test_helper"

class ContactTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "requires an individual or business contact type" do
    contact = @workspace.contacts.build(name: "Ada", email: "ada@example.com", role_names: %w[vendor])

    assert_not contact.valid?
    assert_includes contact.errors[:contact_kind], "can't be blank"
  end

  test "requires at least one role" do
    contact = @workspace.contacts.build(name: "Ada", email: "ada@example.com")

    assert_not contact.valid?
    assert_includes contact.errors[:roles], "must include at least one role"
  end

  test "supports several roles without duplicate contacts" do
    contact = @workspace.contacts.create!(name: "Ada", contact_kind: "individual", email: "ada@example.com", role_names: %w[vendor customer])

    assert_equal %w[vendor customer], contact.role_names
    assert_equal 1, @workspace.contacts.where(name: "Ada").count
  end

  test "updates roles through the contact" do
    contact = @workspace.contacts.create!(name: "Ada", contact_kind: "individual", email: "ada@example.com", role_names: %w[vendor customer])

    contact.update!(role_names: %w[customer])

    assert_equal %w[customer], contact.reload.role_names
  end

  test "filters contacts by role" do
    vendor = @workspace.contacts.create!(name: "Vendor", contact_kind: "business", email: "vendor@example.com", role_names: %w[vendor])
    @workspace.contacts.create!(name: "Customer", contact_kind: "individual", email: "customer@example.com", role_names: %w[customer])

    assert_equal [ vendor ], @workspace.contacts.with_role("vendor")
  end

  test "requires an email" do
    contact = @workspace.contacts.build(name: "Ada", contact_kind: "individual", role_names: %w[vendor])

    assert_not contact.valid?
    assert_includes contact.errors[:email], "can't be blank"
  end

  test "links only the expenses it was paid" do
    vendor = create_vendor("Fuel Station")
    expense = create_expense_for(vendor)
    create_expense_for(create_vendor("Other Vendor"))

    assert_equal [ expense ], vendor.paid_expenses
  end

  private
    def create_vendor(name)
      @workspace.contacts.create!(
        name: name,
        contact_kind: "business",
        email: "#{name.parameterize}@example.com",
        role_names: %w[vendor]
      )
    end

    def create_expense_for(contact)
      @bank ||= @workspace.accounts.create!(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
      @fuel ||= @workspace.accounts.create!(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")

      @workspace.expenses.create!(
        payment_date: Date.current,
        payment_account: @bank,
        payee_contact: contact,
        memo: "Generator fuel",
        expense_lines_attributes: [ { account: @fuel, description: "Fuel", amount_kobo: 4_000_000, position: 0 } ]
      )
    end
end
