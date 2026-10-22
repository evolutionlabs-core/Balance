class BackfillCustomPaymentTermsOnInvoices < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE invoices SET payment_terms = 'custom' WHERE payment_terms IS NULL"
  end

  def down
  end
end
