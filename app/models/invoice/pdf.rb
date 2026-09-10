require "prawn"
require "prawn/table"

class Invoice::Pdf
  def initialize(invoice)
    @invoice = invoice
    @document = Prawn::Document.new(page_size: "A4", margin: 40,
      info: { Title: "Invoice #{invoice.id}", Creator: "Balance" })
    @document.font_families.update("Liberation Sans" => {
      normal: Rails.root.join("app/assets/fonts/liberation/LiberationSans-Regular.ttf").to_s,
      bold: Rails.root.join("app/assets/fonts/liberation/LiberationSans-Bold.ttf").to_s
    })
    @document.font "Liberation Sans", size: 10
    @document.fill_color "262626"
  end

  def render
    header
    customer
    lines
    totals
    @document.number_pages "<page> / <total>", at: [ 0, -18 ], width: @document.bounds.width,
      align: :right, size: 8, color: "737373"
    @document.render
  end

  private
    def header
      @document.text "INVOICE", size: 22, style: :bold, color: "0F7082"
      @document.move_down 18
      business = [ party_detail(:business_name, @invoice.workspace.name),
        party_detail(:business_email, @invoice.user.email_address),
        party_detail(:business_address, @invoice.workspace.address) ].compact_blank.join("\n")
      @document.table([ [ business, "Invoice date\nDue date", "#{date(@invoice.issue_date)}\n#{date(@invoice.due_date)}" ] ],
        width: @document.bounds.width, column_widths: [ 285, 105, @document.bounds.width - 390 ],
        cell_style: { borders: [], padding: [ 0, 0, 16, 0 ], leading: 5 }) do |table|
        table.column(1).text_color = "737373"
        table.column(2).align = :right
      end
    end

    def customer
      details = [ party_detail(:bill_to_name, @invoice.contact&.name),
        party_detail(:bill_to_email, @invoice.contact&.email),
        party_detail(:bill_to_address, @invoice.contact&.address) ].compact_blank
      @document.table([ [ "BILL TO" ], [ details.presence&.join("\n") || "No customer selected" ] ],
        width: @document.bounds.width, cell_style: { borders: [], background_color: "F4F8F8", padding: 16, leading: 4 }) do |table|
        table.row(0).size = 8
        table.row(0).text_color = "737373"
        table.row(0).padding_bottom = 0
      end
      @document.move_down 24
    end

    def lines
      rows = @invoice.invoice_lines.map do |line|
        [ line.description.presence || "—", line.quantity&.to_s("F") || "—",
          line.rate_minor ? money(line.rate_minor) : "—", money(line.amount_minor) ]
      end
      @document.table([ [ "Description", "Qty", "Rate", "Amount" ], *rows ], header: true,
        width: @document.bounds.width, column_widths: [ 230, 45, 120, @document.bounds.width - 395 ],
        cell_style: { borders: [ :bottom ], border_color: "E5E5E5", border_width: 0.5, padding: [ 12, 4 ] }) do |table|
        table.row(0).text_color = "737373"
        table.row(0).size = 9
        table.row(0).background_color = "FFFFFF"
        table.columns(1..3).align = :right
      end
      if rows.empty?
        @document.move_down 12
        @document.text "No line items added", color: "737373"
      end
    end

    def totals
      @document.move_down 24
      @document.table([ [ "Subtotal", money(@invoice.subtotal_minor) ], [ "Total due", money(@invoice.total_minor) ] ],
        position: :right, width: 260, column_widths: [ 100, 160 ],
        cell_style: { borders: [], padding: [ 12, 0 ] }) do |table|
        table.column(1).align = :right
        table.row(0).text_color = "737373"
        table.row(1).borders = [ :top ]
        table.row(1).border_color = "E5E5E5"
        table.row(1).font_style = :bold
        table.row(1).size = 14
      end
    end

    def party_detail(attribute, default)
      value = @invoice.public_send(attribute)
      value.nil? ? default : value
    end

    def date(value)
      value&.strftime("%b %-d, %Y") || "—"
    end

    def money(minor)
      ApplicationController.helpers.minor_currency(minor, @invoice.currency_code)
    end
end
