require "application_system_test_case"

class BillLineEditorTest < ApplicationSystemTestCase
  test "removing a saved line deletes it when the draft is saved" do
    workspace = workspaces(:chidi_supplies)
    ledger = workspace.provision_ledger!
    rent = ledger.accounts.find_by!(key: "rent")
    utilities = ledger.accounts.find_by!(key: "utilities")
    bill = workspace.bills.create!(
      user: users(:three), vendor: workspace.vendors.create!(name: "Lagos Landlords"), bill_date: Date.current,
      bill_lines_attributes: [
        { account_id: rent.id, description: "Office rent", amount: "500.00", position: 0 },
        { account_id: utilities.id, description: "Power", amount: "80.00", position: 1 }
      ]
    )
    users(:three).update!(password: "password")

    visit new_session_path
    fill_in "Email", with: users(:three).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path

    visit edit_bill_path(bill)
    assert_selector "[data-amount-lines-target='total']", text: "580.00"

    within all("[data-amount-lines-target='row']").last do
      click_on "Remove line"
    end
    assert_selector "[data-amount-lines-target='total']", text: "500.00"

    click_on "Save draft"
    assert_current_path bill_path(bill)

    assert_equal [ "Office rent" ], bill.reload.bill_lines.map(&:description)
    assert_equal 50_000, bill.total_kobo
  end
end
