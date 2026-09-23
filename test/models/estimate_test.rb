require "test_helper"

class EstimateTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @other_workspace = workspaces(:bola_shop)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Estimate Customer", customer_type: "business", email: "estimate@example.com", address: "12 Allen Ave")
    @project = @workspace.projects.create!(customer: @customer, name: "Estimate Villa")
    @income_account = @workspace.accounts.create!(name: "Estimate Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    @service = @workspace.services.create!(name: "Hosting service", income_account: @income_account)
  end

  test "prefills billing address from customer and totals lines in kobo" do
    estimate = @workspace.estimates.build(
      user: @user, customer: @customer, project: @project,
      line_items_attributes: {
        "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" },
        "1" => { service: @service, description: "Domain", quantity: "1", rate: "15000" }
      }
    )

    assert estimate.valid?, estimate.errors.full_messages.to_sentence
    assert_equal "12 Allen Ave", estimate.bill_to_address
    assert_equal 12 * 500_000 + 1_500_000, estimate.total_minor
    assert_equal "draft", estimate.status
  end

  test "rejects customer from another workspace" do
    other_customer = @other_workspace.customers.create!(name: "Other", customer_type: "single", email: "other@example.com")
    estimate = @workspace.estimates.build(user: @user, customer: other_customer, project: @project)

    assert_not estimate.valid?
    assert_includes estimate.errors[:customer], "must belong to the workspace"
  end

  test "allows free-form lines and rejects services outside the workspace" do
    other_income = @other_workspace.accounts.create!(name: "Other Estimate Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
    foreign_service = @other_workspace.services.create!(name: "Foreign estimate service", income_account: other_income)

    missing = @workspace.estimates.build(user: @user, customer: @customer, project: @project,
      line_items_attributes: { "0" => { description: "Work", quantity: 1, rate: 100 } })
    foreign = @workspace.estimates.build(user: @user, customer: @customer, project: @project,
      line_items_attributes: { "0" => { service: foreign_service, description: "Work", quantity: 1, rate: 100 } })

    assert missing.valid?, missing.errors.full_messages.to_sentence
    assert_not foreign.valid?
    assert_includes foreign.line_items.first.errors[:service], "must belong to the workspace"
  end

  test "rejects project of another customer" do
    other_customer = @workspace.customers.create!(name: "Other", customer_type: "single", email: "other2@example.com")
    estimate = @workspace.estimates.build(user: @user, customer: other_customer, project: @project)

    assert_not estimate.valid?
    assert_includes estimate.errors[:project], "must belong to the same customer as the estimate"
  end

  test "lifecycle moves draft to sent to approved or declined and back to draft" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert estimate.send_to_client!
    assert estimate.sent?
    assert estimate.approve!
    assert estimate.approved?

    declined = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    declined.send_to_client!
    assert declined.decline!
    assert declined.declined?
    assert declined.reopen!
    assert declined.draft?
  end

  test "rejects transitions outside the lifecycle" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert_raises(AASM::InvalidTransition) { estimate.approve! }
    assert_raises(AASM::InvalidTransition) { estimate.decline! }
    assert_raises(AASM::InvalidTransition) { estimate.reopen! }
    assert estimate.reload.draft?
  end

  test "converts an approved estimate to invoiced and rejects other states" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    estimate.send_to_client!

    assert_raises(AASM::InvalidTransition) { estimate.convert_to_invoice! }
    assert estimate.reload.sent?

    estimate.approve!

    assert estimate.convert_to_invoice!
    assert estimate.invoiced?
  end

  test "invoiced is terminal" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    estimate.send_to_client!
    estimate.approve!
    estimate.convert_to_invoice!

    assert_raises(AASM::InvalidTransition) { estimate.send_to_client! }
    assert_raises(AASM::InvalidTransition) { estimate.approve! }
    assert_raises(AASM::InvalidTransition) { estimate.decline! }
    assert_raises(AASM::InvalidTransition) { estimate.reopen! }
    assert estimate.reload.invoiced?
  end

  test "build_invoice copies the approved snapshot with net-15 terms" do
    estimate = @workspace.estimates.create!(
      user: @user, customer: @customer, project: @project,
      line_items_attributes: {
        "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" }
      }
    )

    invoice = estimate.build_invoice(user: @user)

    assert invoice.new_record?
    assert_equal @workspace, invoice.workspace
    assert_equal @user, invoice.user
    assert_equal @customer, invoice.customer
    assert_equal @project, invoice.project
    assert_equal estimate, invoice.estimate
    assert_equal "NGN", invoice.currency_code
    assert_equal Date.current, invoice.issue_date
    assert_equal Date.current + 15.days, invoice.due_date
    assert_equal estimate.bill_to_name, invoice.bill_to_name
    assert_equal estimate.bill_to_email, invoice.bill_to_email
    assert_equal estimate.bill_to_address, invoice.bill_to_address
    assert_equal [ "Hosting" ], invoice.invoice_lines.map(&:description)
    assert_equal [ BigDecimal("12") ], invoice.invoice_lines.map(&:quantity)
    assert_equal [ 500_000 ], invoice.invoice_lines.map(&:rate_minor)
    assert_equal [ @service ], invoice.invoice_lines.map(&:service)

    invoice.save!

    assert_equal [ @income_account ], invoice.invoice_lines.map(&:account)
    assert_equal 12 * 500_000, invoice.total_minor
    assert_equal format("INV-%06d", invoice.id), invoice.invoice_number
  end

  test "free-form estimates convert without requiring an income account" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project,
      line_items_attributes: [ { description: "Custom work", quantity: 3, rate: 125 } ])
    invoice = estimate.build_invoice(user: @user)
    invoice.save!

    assert_equal 37_500, invoice.total_minor
    assert_equal "Custom work", invoice.invoice_lines.sole.description
    assert_nil invoice.invoice_lines.sole.service
    assert_nil invoice.invoice_lines.sole.account
    assert invoice.draft?
    assert_nil invoice.journal_entry
  end

  test "allows edits after sending" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)
    estimate.send_to_client!

    assert estimate.update(notes: "changed")
    assert_equal "changed", estimate.reload.notes
  end

  test "omitted saved rows are removed on update" do
    estimate = @workspace.estimates.create!(
      user: @user, customer: @customer, project: @project,
      line_items_attributes: {
        "0" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" },
        "1" => { service: @service, description: "Domain", quantity: "1", rate: "15000" }
      }
    )
    kept = estimate.line_items.find_by(description: "Hosting")

    assert_difference("EstimateLineItem.count", -1) do
      estimate.update!(line_items_attributes: { "-#{kept.id}" => { service: @service, description: "Hosting", quantity: "12", rate: "5000" } })
    end

    assert_equal [ "Hosting" ], estimate.reload.line_items.pluck(:description)
  end

  test "ignores a blank placeholder when another line is complete" do
    estimate = @workspace.estimates.build(
      user: @user,
      customer: @customer,
      project: @project,
      line_items_attributes: {
        "0" => { service: @service, description: "Hosting", quantity: 2, rate: 20, amount: 40 },
        "1" => { service_id: "", description: "", quantity: 1, rate: 0, amount: 0 }
      }
    )

    assert estimate.valid?, estimate.errors.full_messages.to_sentence
    assert_equal 1, estimate.line_items.size
  end

  test "number derives from id" do
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: @project)

    assert_equal format("EST-%06d", estimate.id), estimate.number
  end
end
