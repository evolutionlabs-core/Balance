module OverviewsHelper
  CHART_SERIES_COLORS = %w[#0d9488 #6366f1 #d97706 #e11d48 #0284c7 #65a30d].freeze
  CHART_REST_COLOR = "#a3a3a3".freeze
  CHART_CASH_COLOR = "#0f7082".freeze
  INCOME_COLOR, EXPENSE_COLOR = CHART_SERIES_COLORS.first(2)
  CURRENT_COLOR = CHART_SERIES_COLORS.first
  OVERDUE_COLOR = CHART_SERIES_COLORS.third

  def overview_panel_class
    "min-w-0 rounded-xl border border-neutral-200 bg-white p-5 sm:p-6"
  end

  def overview_kpi_change(overview, kpi)
    basis = { period: overview.t("previous_periods.#{overview.days}"), date: (overview.date_range.begin - 1).strftime("%b %-d") }
    percent = kpi.change_percent

    tag.p(class: "mt-3 flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-xs text-neutral-500") do
      if percent.nil?
        tag.span(overview_kpi_basis(overview, kpi, overview.t("kpis.change.when.#{kpi.compared_to}", **basis)))
      else
        safe_join([ overview_change_figure(overview, kpi, percent), tag.span(overview.t("kpis.change.#{kpi.compared_to}", **basis)) ])
      end
    end
  end

  def overview_kpi_basis(overview, kpi, moment)
    basis = kpi.basis_kobo
    amount = money(basis.abs, overview.workspace.currency_code)

    if basis.zero?
      overview.t("kpis.change.was_zero", when: moment)
    elsif kpi.net?
      overview.t("kpis.change.#{basis.positive? ? "was_profit" : "was_loss"}", amount: amount, when: moment)
    else
      overview.t("kpis.change.was", amount: basis.negative? ? "−#{amount}" : amount, when: moment)
    end
  end

  def overview_change_figure(overview, kpi, percent)
    figure = number_to_percentage(percent.abs, precision: percent.abs < 10 ? 1 : 0, strip_insignificant_zeros: true, delimiter: ",")

    if kpi.change_kobo.zero?
      tag.span(figure, class: "font-semibold tabular-nums text-neutral-700")
    else
      rising = kpi.change_kobo.positive?
      tone = rising == kpi.rising_is_good ? "text-emerald-700" : "text-red-700"
      tag.span(class: "inline-flex items-center gap-0.5 font-semibold tabular-nums #{tone}") do
        safe_join([
          inline_svg_tag("icons/arrow-#{rising ? "up" : "down"}-right.svg", class: "size-3.5", aria_hidden: true),
          tag.span(overview.t("kpis.change.#{rising ? "rising" : "falling"}"), class: "sr-only"),
          figure
        ])
      end
    end
  end

  def overview_chart_money_options(overview)
    { prefix: currency_symbol(overview.workspace.currency_code), thousands: "," }
  end

  def overview_slice_colors(slices)
    slices.each_with_index.map { |slice, index| slice.rest ? CHART_REST_COLOR : CHART_SERIES_COLORS.fetch(index) }
  end

  def overview_share(part, whole)
    if whole.positive?
      number_to_percentage(part * 100.0 / whole, precision: 0)
    end
  end
end
