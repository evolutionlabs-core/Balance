require "test_helper"

system(Tailwindcss::Commands.command_env(verbose: false), *Tailwindcss::Commands.compile_command(silent: true), exception: true)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    Capybara.default_max_wait_time = 5
    page.driver.browser.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: true)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
    page.execute_script("try { localStorage.clear() } catch (error) {}")
  end
end
