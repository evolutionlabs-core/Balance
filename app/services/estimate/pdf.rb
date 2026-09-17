require "prawn"
require "prawn/table"

class Estimate::Pdf
  def initialize(estimate)
    @estimate = estimate
    @document = Prawn::Document.new(page_size: "A4", margin: 40,
      info: { Title: "Estimate", Creator: "Balance" })
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
      @document.text "ESTIMATE", size: 22, style: :bold, color: "0F7082"
      @document.move_down 18
      name = @estimate.business_name || @estimate.workspace.name
      email = @estimate.business_email
      address = @estimate.business_address || @estimate.workspace.address
      business = [ name.presence || "—", email.presence || "—", address.presence ].compact.join("\n")
      @document.table([ [ business ] ],
        width: @document.bounds.width,
        cell_style: { borders: [], padding: [ 0, 0, 16, 0 ], leading: 5 })
    end

    def customer
      name = @estimate.bill_to_name || @estimate.customer&.name
      email = @estimate.bill_to_email || @estimate.customer&.email
      address = @estimate.bill_to_address || @estimate.customer&.address
      details = if name.present? || email.present? || address.present?
        [ name.presence || "—", email.presence || "—", address.presence ].compact
      end
      @document.table([ [ "BILL TO" ], [ details.presence&.join("\n") || "No customer selected" ] ],
        width: @document.bounds.width, cell_style: { borders: [], background_color: "F4F8F8", padding: 16, leading: 4 }) do |table|
        table.row(0).size = 8
        table.row(0).text_color = "737373"
        table.row(0).padding_bottom = 0
      end
      @document.move_down 24
    end

    def lines
      rows = @estimate.line_items.map do |line|
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
      @document.table([ [ "Subtotal", money(@estimate.subtotal_minor) ], [ "Total", money(@estimate.total_minor) ] ],
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

    def notes
      return if @estimate.notes.blank?

      @document.move_down 24
      @document.text "Notes", style: :bold
      @document.move_down 6
      @document.text @estimate.notes
    end

    def money(minor)
      ApplicationController.helpers.minor_currency(minor, @estimate.currency_code)
    end
end
