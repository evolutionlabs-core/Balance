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
    vendor = create_vendor(@workspace)
    other = create_vendor(@workspace, name: "Other Vendor")
    expense = expense_for(vendor)
    expense_for(other)

    assert_equal [ expense ], vendor.paid_expenses
  end

  test "refuses to delete a contact with expenses" do
    vendor = create_vendor(@workspace)
    expense_for(vendor)

    assert_not vendor.destroy
    assert_match(/paid expenses/, vendor.errors[:base].to_sentence)
    assert Contact.exists?(vendor.id)
  end

  private
    def expense_for(contact)
      create_expense(@workspace,
        payee_contact: contact,
        payment_account: @bank ||= create_payment_account(@workspace),
        category: @fuel ||= create_expense_account(@workspace))
    end
end
