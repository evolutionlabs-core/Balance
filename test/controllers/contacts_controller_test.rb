require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
  end

  test "creates a contact with several roles" do
    assert_difference("Contact.count", 1) do
      post contacts_path, params: {
        contact: {
          name: "Ada Supplies",
          contact_kind: "business",
          email: "accounts@example.com",
          phone: "08000000000",
          active: true,
          role_names: %w[vendor customer]
        }
      }
    end

    contact = @workspace.contacts.order(:id).last
    assert_redirected_to contacts_path
    assert_equal %w[vendor customer], contact.role_names
    assert_equal "business", contact.contact_kind
  end

  test "prefills the vendor role from the new expense link" do
    get new_contact_path(role: "vendor")

    assert_response :success
    assert_select "input#contact_role_names_vendor[checked]"
    assert_select "input#contact_role_names_customer:not([checked])"
  end

  test "filters the contact list by role" do
    vendor = @workspace.contacts.create!(name: "Vendor", contact_kind: "business", email: "vendor@example.com", role_names: %w[vendor])
    customer = @workspace.contacts.create!(name: "Customer", contact_kind: "individual", email: "customer@example.com", role_names: %w[customer])

    get contacts_path(role: "vendor")

    assert_response :success
    assert_select "tr##{dom_id(vendor)}"
    assert_select "tr##{dom_id(customer)}", count: 0
  end

  test "deactivates a contact without deleting it" do
    contact = @workspace.contacts.create!(name: "Vendor", contact_kind: "business", email: "vendor@example.com", role_names: %w[vendor])

    patch contact_path(contact), params: {
      contact: { name: contact.name, contact_kind: contact.contact_kind, email: contact.email, active: false, role_names: %w[vendor] }
    }

    assert_redirected_to contacts_path
    assert_not contact.reload.active?
    assert Contact.exists?(contact.id)
  end

  test "cannot access another workspace contact" do
    contact = workspaces(:bola_shop).contacts.create!(name: "Other", contact_kind: "business", email: "other@example.com", role_names: %w[vendor])

    get edit_contact_path(contact)

    assert_response :not_found
  end

  test "shows a contact with the expenses paid to it" do
    vendor = create_vendor(@workspace)
    expense = expense_for(vendor)

    get contact_path(vendor)

    assert_response :success
    assert_select "tr##{dom_id(expense)}"
    assert_select "a[href=?]", expense_path(expense)
  end

  test "omits expenses paid to another contact" do
    vendor = create_vendor(@workspace)
    other_expense = expense_for(create_vendor(@workspace, name: "Other Vendor"))

    get contact_path(vendor)

    assert_response :success
    assert_select "tr##{dom_id(other_expense)}", count: 0
  end

  test "cannot view another workspace contact" do
    contact = workspaces(:bola_shop).contacts.create!(name: "Other", contact_kind: "business", email: "other@example.com", role_names: %w[vendor])

    get contact_path(contact)

    assert_response :not_found
  end

  test "returns to the contact page after editing from it" do
    contact = create_vendor(@workspace)

    patch contact_path(contact), params: {
      return_to: contact_path(contact),
      contact: { name: "Renamed", contact_kind: "business", email: contact.email, role_names: %w[vendor] }
    }

    assert_redirected_to contact_path(contact)
  end

  test "ignores an off-site return path" do
    contact = create_vendor(@workspace)

    patch contact_path(contact), params: {
      return_to: "https://evil.example/steal",
      contact: { name: "Renamed", contact_kind: "business", email: contact.email, role_names: %w[vendor] }
    }

    assert_redirected_to contacts_path
  end

  private
    def expense_for(contact)
      create_expense(@workspace,
        payee_contact: contact,
        payment_account: @bank ||= create_payment_account(@workspace),
        category: @fuel ||= create_expense_account(@workspace))
    end
end
