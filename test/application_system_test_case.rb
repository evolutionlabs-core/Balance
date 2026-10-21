require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    Capybara.default_max_wait_time = 5
    page.driver.browser.execute_cdp("Page.bringToFront")
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
    page.execute_script("try { localStorage.clear() } catch (error) {}")
  end
end
