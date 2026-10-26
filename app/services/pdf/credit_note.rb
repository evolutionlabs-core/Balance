require "prawn"
require "prawn/table"

class Pdf::CreditNote
  def initialize(credit_note)
    @credit_note = credit_note
    @document = Prawn::Document.new(page_size: "A4", margin: 40,
      info: { Title: "Credit note #{credit_note.number}", Creator: "Balance" })
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
    notes
    @document.number_pages "<page> / <total>", at: [ 0, -18 ], width: @document.bounds.width,
      align: :right, size: 8, color: "737373"
    @document.render
  end

  private
    def header
      @document.text "CREDIT NOTE", size: 22, style: :bold, color: "0F7082"
      @document.move_down 18
      workspace = @credit_note.workspace
      business = [ workspace.name, @credit_note.user.email_address, workspace.address.presence ].compact.join("\n")
      details = [ [ "Credit note no.", @credit_note.number ], [ "Date", @credit_note.issued_on.strftime("%b %-d, %Y") ] ]
      details << [ "Invoice", @credit_note.invoice.invoice_number ] if @credit_note.invoice
      @document.table([ [ business, details.map(&:first).join("\n"), details.map(&:last).join("\n") ] ],
        width: @document.bounds.width, column_widths: [ 285, 105, @document.bounds.width - 390 ],
        cell_style: { borders: [], padding: [ 0, 0, 16, 0 ], leading: 5 }) do |table|
        table.column(1).text_color = "737373"
        table.column(2).align = :right
      end
    end

    def customer
      details = [ @credit_note.bill_to_name.presence || @credit_note.customer.name, @credit_note.bill_to_email.presence || "—",
        @credit_note.bill_to_address.presence ].compact
      @document.table([ [ "CREDIT TO" ], [ details.join("\n") ] ],
        width: @document.bounds.width, cell_style: { borders: [], background_color: "F4F8F8", padding: 16, leading: 4 }) do |table|
        table.row(0).size = 8
        table.row(0).text_color = "737373"
        table.row(0).padding_bottom = 0
      end
      @document.move_down 24
    end

    def lines
      rows = @credit_note.lines.map do |line|
        [ line.description, line.quantity&.to_s("F")&.delete_suffix(".0") || "—",
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
    end

    def totals
      @document.move_down 24
      rows = []
      if @credit_note.discounted?
        rows << [ "Subtotal", money(@credit_note.subtotal_minor) ]
        rows << [ @credit_note.discount_label, "−#{money(@credit_note.discount_minor)}" ]
      end
      rows << [ "Total credit", money(@credit_note.total_minor) ]
      @document.table(rows, position: :right, width: 260, column_widths: [ 100, 160 ],
        cell_style: { borders: [], padding: [ 12, 0 ] }) do |table|
        table.column(1).align = :right
        last = rows.size - 1
        table.rows(0...last).text_color = "737373"
        table.row(last).text_color = "262626"
        table.row(last).borders = [ :top ]
        table.row(last).border_color = "E5E5E5"
        table.row(last).font_style = :bold
        table.row(last).size = 14
      end
    end

    def notes
      return if @credit_note.notes.blank?

      @document.move_down 28
      @document.text "NOTE", size: 8, color: "737373"
      @document.move_down 4
      @document.text @credit_note.notes, leading: 3
    end

    def money(minor)
      ApplicationController.helpers.minor_currency(minor, @credit_note.currency_code)
    end
end
