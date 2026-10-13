class RenameReceivableApplicationsToInvoicePayments < ActiveRecord::Migration[8.1]
  def change
    # The ReceivableApplication rows are payments received against invoices.
    # "Application" was accounting shorthand the domain does not need.
    rename_table :receivable_applications, :invoice_payments
    rename_column :invoice_payments, :reverses_receivable_application_id, :reverses_invoice_payment_id
  end
end
