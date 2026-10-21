module ReportsHelper
  def statement_figure(kobo)
    figure = number_with_precision(BigDecimal(kobo.abs) / 100, precision: 2, delimiter: ",")
    kobo.negative? ? "(#{figure})" : figure
  end

  STATEMENT_ROW_CLASSES = {
    section: "font-semibold text-neutral-950",
    group: "font-medium text-neutral-800",
    account: "font-normal text-neutral-700",
    subtotal: "font-medium text-neutral-900",
    section_total: "font-semibold text-neutral-950",
    result: "font-semibold text-neutral-950",
    grand_total: "font-semibold text-neutral-950"
  }.freeze

  STATEMENT_LABEL_INDENT = {
    section: "pl-0", group: "pl-3 sm:pl-4", account: "pl-6 sm:pl-8",
    subtotal: "pl-3 sm:pl-4", section_total: "pl-0", result: "pl-0", grand_total: "pl-0"
  }.freeze

  STATEMENT_FIGURE_RULES = {
    subtotal: "border-t border-neutral-300",
    section_total: "border-t border-neutral-400",
    result: "border-t border-neutral-400",
    grand_total: "border-t border-neutral-400 border-b-[3px] border-b-neutral-900 border-double"
  }.freeze

  def statement_row_class(line)
    STATEMENT_ROW_CLASSES.fetch(line.kind)
  end

  def statement_label_indent(line)
    STATEMENT_LABEL_INDENT.fetch(line.kind)
  end

  def statement_figure_rule(line)
    STATEMENT_FIGURE_RULES[line.kind]
  end

  def statement_top_space(line, index)
    if index.zero?
      ""
    elsif line.kind.in?(%i[section grand_total result])
      "pt-5"
    elsif line.kind == :group
      "pt-3"
    else
      ""
    end
  end

  def report_export_link
    link_to "Export CSV", url_for(request.query_parameters.merge(format: :csv)), class: secondary_button_class(size: :compact), data: { turbo: false }
  end
end
