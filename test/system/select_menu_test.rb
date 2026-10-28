require "application_system_test_case"

class SelectMenuTest < ApplicationSystemTestCase
  setup do
    users(:one).update!(password: "password")
    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_current_path root_path
    page.execute_script("window.controllerErrors = []; const log = console.error; console.error = (...args) => { window.controllerErrors.push(args.map(String).join(' ')); log(...args) }")
  end

  test "keeps its menu when a page with it is cached and shown again" do
    page.execute_script("Turbo.visit('/invoices/new')")
    assert_current_path new_invoice_path
    find("[data-select-menu-target=button]", match: :first).click
    page.execute_script("document.querySelector('a[href=\"/customers\"]').click()")
    assert_current_path customers_path

    page.execute_script("Turbo.visit('/invoices/new')")
    assert_current_path new_invoice_path
    find("[data-select-menu-target=button]", match: :first).click
    assert_selector "[role=option]", text: "Net 15"

    assert_empty page.evaluate_script("window.controllerErrors")
  end

  test "does not leave an open menu behind after going back" do
    page.execute_script("Turbo.visit('/customers')")
    assert_current_path customers_path
    page.execute_script("Turbo.visit('/invoices/new')")
    assert_current_path new_invoice_path
    find("[data-select-menu-target=button]", match: :first).click
    assert_selector "body > [data-select-menu-target=menu]:not(.hidden)"

    page.go_back
    assert_current_path customers_path
    assert_no_selector "[data-select-menu-target=menu]", visible: :all
    page.go_forward
    assert_current_path new_invoice_path
    assert_selector "[data-controller~=select-menu] > [data-select-menu-target=menu]", visible: :all

    assert_empty page.evaluate_script("window.controllerErrors")
  end
end
