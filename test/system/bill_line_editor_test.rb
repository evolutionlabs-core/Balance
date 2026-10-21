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
    page.execute_script(<<~JS)
      window.__marker = "loaded"
      window.__events = []
      const log = (label) => window.__events.push(label + " @" + Math.round(performance.now()))
      for (const name of ["turbo:load", "turbo:render", "turbo:morph", "turbo:visit", "turbo:before-render", "turbo:before-fetch-request", "turbo:submit-start", "turbo:frame-load", "focusin"]) {
        document.addEventListener(name, (event) => log(name + " " + (event.detail?.url || event.target?.name || event.target?.id || "")), true)
      }
      addEventListener("beforeunload", () => log("beforeunload"))
      addEventListener("error", (event) => log("error " + event.message))
      addEventListener("unhandledrejection", (event) => log("rejection " + event.reason))
      document.addEventListener("click", (event) => log("click " + event.target.tagName + "." + (event.target.className?.baseVal ?? event.target.className).slice(0, 40) + " in " + (event.target.closest("button")?.dataset.action || "-")), true)
      const controller = Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=amount-lines]"), "amount-lines")
      const original = controller?.removeLine?.bind(controller)
      if (controller) controller.removeLine = (event) => { log("removeLine " + event.currentTarget?.tagName); try { original(event) } catch (error) { log("threw " + error.message) } }
      new MutationObserver((records) => records.forEach((record) => record.removedNodes.length && log("removed " + [...record.removedNodes].map((node) => node.nodeName).join(",")))).observe(document.body, { childList: true, subtree: true })
    JS
    puts "BEFORE: stimulus=#{page.evaluate_script("!!window.Stimulus && !!Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~=amount-lines]'), 'amount-lines')")} nav=#{page.evaluate_script("performance.getEntriesByType('navigation')[0]?.type")}"
    within all("[data-amount-lines-target='row']").last do
      find("[data-amount-lines-target='amount']").set("90.00")
    end
    puts "AFTER SET: value=#{all("[data-amount-lines-target='amount']").last.value} total=#{find("[data-amount-lines-target='total']").text} active=#{page.evaluate_script("document.activeElement?.name || document.activeElement?.tagName")}"
    sleep 2
    puts "LATER: marker=#{page.evaluate_script("window.__marker").inspect} value=#{all("[data-amount-lines-target='amount']").last.value} total=#{find("[data-amount-lines-target='total']").text} stimulus=#{page.evaluate_script("!!window.Stimulus && !!Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller~=amount-lines]'), 'amount-lines')")}"
    puts "EVENTS: #{page.evaluate_script("window.__events").inspect}"
    puts "LOGS: #{page.driver.browser.logs.get(:browser).map { |entry| "#{entry.level} #{entry.message}" }.first(15).inspect}"
    assert_selector "[data-amount-lines-target='total']", text: "590.00"

    within all("[data-amount-lines-target='row']").last do
      click_on "Remove line"
    end
    sleep 1
    puts "AFTER CLICK: rows=#{page.evaluate_script("[...document.querySelectorAll('[data-amount-lines-target=row]')].map(r => [r.hidden, r.querySelector('input[name$=\"[_destroy]\"]')?.value, !!r.querySelector('input[name$=\"[id]\"]')].join('/'))").inspect} total=#{find("[data-amount-lines-target='total']").text}"
    puts "EVENTS2: #{page.evaluate_script("window.__events").inspect}"
    puts "LOGS2: #{page.driver.browser.logs.get(:browser).map { |entry| "#{entry.level} #{entry.message}" }.first(15).inspect}"
    assert_selector "[data-amount-lines-target='total']", text: "500.00"

    puts "AFTER CLICK: rows=#{page.evaluate_script("[...document.querySelectorAll('[data-amount-lines-target=row]')].map(r => [r.hidden, r.querySelector('input[name$=\"[_destroy]\"]')?.value, !!r.querySelector('input[name$=\"[id]\"]')].join('/'))").inspect} total=#{find("[data-amount-lines-target='total']", visible: :all).text(:all)}"
    puts "EVENTS2: #{page.evaluate_script("window.__events").inspect}"
    click_on "Save draft"
    assert_current_path bill_path(bill)

    assert_equal [ "Office rent" ], bill.reload.bill_lines.map(&:description)
    assert_equal 50_000, bill.total_kobo
  end
end
