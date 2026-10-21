class InvoiceDelivery
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :to, :string
  attribute :subject, :string
  attribute :message, :string
  attribute :send_email, :boolean, default: false
  attribute :via, :string

  attr_reader :invoice

  validates :to, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :subject, presence: true

  def initialize(invoice:, **attributes)
    @invoice = invoice
    super(**attributes)
    self.to ||= invoice.bill_to_email.nil? ? invoice.customer&.email : invoice.bill_to_email
    self.subject ||= "Invoice #{invoice.invoice_number} from #{sender_name}"
    self.message ||= default_message
  end

  def sender_name
    invoice.business_name.nil? ? invoice.workspace.name : invoice.business_name
  end

  def sender_email
    invoice.business_email.nil? ? invoice.user.email_address : invoice.business_email
  end

  def deliver_later
    InvoiceMailer.with(invoice: invoice, to: to, subject: subject, message: message).issued.deliver_later
  end

  private
    def default_message
      due = invoice.due_date ? ", due #{invoice.due_date.strftime("%b %-d, %Y")}" : ""

      "Here is invoice #{invoice.invoice_number}#{due}. The PDF is attached.\n\n" \
        "Thank you for your business,\n#{sender_name}"
    end
end
