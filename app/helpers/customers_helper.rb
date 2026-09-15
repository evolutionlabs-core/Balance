module CustomersHelper
  def customer_status(customer)
    status_badge(customer.active? ? "Active" : "Inactive", tone: customer.active? ? :success : :neutral)
  end
end
