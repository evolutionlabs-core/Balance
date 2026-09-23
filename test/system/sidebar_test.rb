require "application_system_test_case"

class SidebarTest < ApplicationSystemTestCase
  setup do
    @workspace = workspaces(:ada_store)
    users(:one).update!(password: "password")
    sign_in
  end

  teardown do
    resize_to(1400, 1400)
  end

  test "mobile drawer starts closed and occupies no width" do
    resize_to(390, 844)
    visit overview_path

    assert_selector 'button[aria-label="Open navigation"]'
    assert_no_selector "#sidebar-panel", visible: true
    assert_equal "false", hamburger_expanded
    assert_content_left_edge
    assert_no_document_overflow
  end

  test "mobile drawer opens as an overlay and traps focus" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click

    assert_selector "#sidebar-panel", visible: true
    assert_equal "true", hamburger_expanded
    assert backdrop_visible
    assert_equal "Close navigation", active_element_label
    assert page.evaluate_script("document.body.classList.contains('overflow-hidden')")
    assert page.evaluate_script("document.getElementById('sidebar-panel').matches(':modal')")
    assert_content_left_edge
  end

  test "mobile drawer contains keyboard focus while open" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    page.evaluate_script("document.querySelector('[data-menu-target=\"button\"]').focus()")
    press_tab

    assert_equal "Close navigation", active_element_label

    press_shift_tab
    assert_includes active_element_text, users(:one).full_name
  end

  test "mobile drawer closes with Escape and restores focus" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    press_escape

    assert_no_selector "#sidebar-panel", visible: true
    assert_equal "false", hamburger_expanded
    assert_equal "Open navigation", active_element_label
    assert_not page.evaluate_script("document.body.classList.contains('overflow-hidden')")
  end

  test "mobile drawer closes from the backdrop and close button" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    page.evaluate_script("document.getElementById('sidebar-panel').click()")
    assert_no_selector "#sidebar-panel", visible: true

    find('button[aria-label="Open navigation"]').click
    find('button[aria-label="Close navigation"]').click
    assert_no_selector "#sidebar-panel", visible: true
    assert_equal "Open navigation", active_element_label
  end

  test "mobile navigation selection closes the drawer, including the current page" do
    resize_to(390, 844)
    visit customers_path

    find('button[aria-label="Open navigation"]').click
    within("#sidebar-panel") { click_on "Customers" }

    assert_current_path customers_path
    assert_no_selector "#sidebar-panel", visible: true

    find('button[aria-label="Open navigation"]').click
    within("#sidebar-panel") { click_on "Expenses" }

    assert_current_path expenses_path
    assert_no_selector "#sidebar-panel", visible: true
  end

  test "mobile drawer starts closed after reload and back navigation" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    assert_selector "#sidebar-panel", visible: true

    page.refresh
    assert_no_selector "#sidebar-panel", visible: true

    find('button[aria-label="Open navigation"]').click
    within("#sidebar-panel") { click_on "Customers" }
    assert_current_path customers_path
    page.go_back
    assert_no_selector "#sidebar-panel", visible: true
    assert_selector "body:not(.overflow-hidden)"
  end

  test "toggling the drawer preserves form input and scroll" do
    resize_to(390, 844)
    visit new_expense_path

    fill_in "Memo", with: "Keep me"
    page.evaluate_script("window.scrollTo(0, 300)")
    scroll_before = page.evaluate_script("window.scrollY")

    find('button[aria-label="Open navigation"]').click
    press_escape

    assert_equal "Keep me", find_field("Memo").value
    assert_equal scroll_before, page.evaluate_script("window.scrollY")
  end

  test "Escape closes the account menu first, then the drawer" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    account_button.click
    assert_equal "true", menu_expanded

    press_escape
    assert_equal "false", menu_expanded
    assert_selector "#sidebar-panel", visible: true

    press_escape
    assert_no_selector "#sidebar-panel", visible: true
  end

  test "drawer keeps backdrop visible at 320, 384, and 412 pixel widths" do
    [ 320, 384, 412 ].each do |width|
      resize_to(width, 800)
      visit overview_path

      assert_no_selector "#sidebar-panel", visible: true
      assert_content_left_edge

      find('button[aria-label="Open navigation"]').click
      drawer_right = page.evaluate_script("document.getElementById('sidebar-panel').getBoundingClientRect().right")
      viewport = page.evaluate_script("window.innerWidth")

      assert drawer_right < viewport, "expected backdrop visible at #{width}px"
      press_escape
    end
  end

  test "tablet widths use the drawer and desktop width uses the static sidebar" do
    resize_to(768, 800)
    visit overview_path
    assert_selector 'button[aria-label="Open navigation"]'
    assert_no_selector "#sidebar-panel", visible: true

    find('button[aria-label="Open navigation"]').click
    assert_selector '#sidebar-panel [aria-current="page"]', text: "Overview"

    resize_to(1023, 800)
    visit overview_path
    assert_selector 'button[aria-label="Open navigation"]'

    resize_to(1024, 800)
    visit overview_path
    assert_no_selector 'button[aria-label="Open navigation"]', visible: true
    assert_selector "#sidebar-panel", visible: true
    assert_not page.evaluate_script("document.getElementById('sidebar-panel').matches(':modal')")
  end

  test "desktop rail preference persists and mobile use does not change it" do
    resize_to(1440, 900)
    visit overview_path

    find('button[aria-label="Collapse sidebar"]').click
    assert_equal "true", page.evaluate_script("localStorage.getItem('balance:sidebar-collapsed')")
    assert_selector "#sidebar-panel"

    visit overview_path
    assert_selector 'button[aria-label="Expand sidebar"]'

    resize_to(390, 844)
    visit overview_path
    find('button[aria-label="Open navigation"]').click
    press_escape
    assert_equal "true", page.evaluate_script("localStorage.getItem('balance:sidebar-collapsed')")

    resize_to(1440, 900)
    visit overview_path
    assert_selector 'button[aria-label="Expand sidebar"]'
    find('button[aria-label="Expand sidebar"]').click
    assert_equal "false", page.evaluate_script("localStorage.getItem('balance:sidebar-collapsed')")
  end

  test "collapsed desktop rail does not clip the account menu" do
    resize_to(1440, 900)
    visit overview_path
    find('button[aria-label="Collapse sidebar"]').click if page.has_selector?('button[aria-label="Collapse sidebar"]')

    account_button.click

    assert_selector "#account-menu", visible: true
    assert page.evaluate_script(<<~JS)
      (() => {
        const panel = document.getElementById("sidebar-panel").getBoundingClientRect()
        const menu = document.getElementById("account-menu")
        const box = menu.getBoundingClientRect()
        return menu.contains(document.elementFromPoint(panel.right + 8, box.top + 20))
      })()
    JS
  end

  test "resizing to desktop clears drawer overlays and scroll locks" do
    resize_to(390, 844)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    account_button.click
    assert_equal "true", menu_expanded

    resize_to(1440, 900)

    assert_selector "body:not(.overflow-hidden)"
    assert_selector "button[aria-label='Account settings for #{users(:one).full_name}'][aria-expanded='false']"
    assert_selector "#sidebar-panel", visible: true
  end

  test "an open drawer covers background actions and yields to dialogs" do
    resize_to(390, 844)
    visit customers_path

    find('button[aria-label="Open navigation"]').click
    assert_raises(Selenium::WebDriver::Error::ElementClickInterceptedError) do
      click_on "New customer", match: :first
    end

    press_escape
    click_on "New customer", match: :first
    assert_selector "#modal dialog[open]", text: "New customer"
    assert_no_selector "#sidebar-panel", visible: true
    assert page.evaluate_script("document.body.classList.contains('overflow-hidden')")
  end

  test "wide invoice content does not create document overflow on mobile" do
    resize_to(390, 844)
    visit invoices_path

    assert_no_document_overflow
  end

  test "key pages fit narrow viewports without document overflow" do
    resize_to(390, 844)

    [ overview_path, customers_path, expenses_path, invoices_path ].each do |path|
      visit path
      assert_no_document_overflow
    end
  end

  test "landscape phone keeps the account control reachable" do
    resize_to(844, 390)
    visit overview_path

    find('button[aria-label="Open navigation"]').click
    assert_selector "#sidebar-panel", visible: true

    identity = account_button
    assert identity.visible?

    identity.click
    assert_equal "true", menu_expanded
    assert_selector "#account-menu", visible: true

    press_escape
    press_escape
    assert_no_selector "#sidebar-panel", visible: true
  end

  private
    def sign_in
      visit new_session_path
      fill_in "Email", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end

    def resize_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end

    def hamburger_expanded
      find('[data-sidebar-target="hamburger"]')["aria-expanded"]
    end

    def menu_expanded
      account_button["aria-expanded"]
    end

    def account_button
      find("button[aria-label='Account settings for #{users(:one).full_name}']")
    end

    def backdrop_visible
      page.evaluate_script("document.getElementById('sidebar-panel').matches(':modal')")
    end

    def active_element_label
      page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    end

    def active_element_text
      page.evaluate_script("document.activeElement.textContent")
    end

    def press_escape
      page.driver.browser.action.send_keys(:escape).perform
    end

    def press_tab
      page.driver.browser.action.send_keys(:tab).perform
    end

    def press_shift_tab
      page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    end

    def assert_content_left_edge
      left = page.evaluate_script("document.querySelector('main').getBoundingClientRect().left")
      assert left < 2, "expected content at the left edge, got #{left}"
    end

    def assert_no_document_overflow
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth + 1"),
        "document overflows the viewport"
    end
end
