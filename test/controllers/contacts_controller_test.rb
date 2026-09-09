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
          address: "12 Market Road, Lagos",
          active: true,
          role_names: %w[vendor customer]
        }
      }
    end

    contact = @workspace.contacts.order(:id).last
    assert_redirected_to contacts_path
    assert_equal %w[vendor customer], contact.role_names
    assert_equal "business", contact.contact_kind
    assert_equal "12 Market Road, Lagos", contact.address
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

  test "updates invoice bill-to fields with a turbo stream" do
    contact = @workspace.contacts.create!(name: "Customer", contact_kind: "business", email: "old@example.com", role_names: %w[customer])

    invoice = @workspace.invoices.create!(user: users(:one), contact: contact)
    patch contact_path(contact, invoice_id: invoice.id), params: {
      contact: {
        name: "Customer",
        contact_kind: "business",
        email: "new@example.com",
        address: "12 Broad Street",
        role_names: %w[customer]
      }
    }, headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='#{dom_id(invoice, :customer)}']"
    assert_equal "12 Broad Street", contact.reload.address
    assert_equal "12 Broad Street", invoice.reload.bill_to_address
  end

  test "cannot access another workspace contact" do
    contact = workspaces(:bola_shop).contacts.create!(name: "Other", contact_kind: "business", email: "other@example.com", role_names: %w[vendor])

    get edit_contact_path(contact)

    assert_response :not_found
  end
end
