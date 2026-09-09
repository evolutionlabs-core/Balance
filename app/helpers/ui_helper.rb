module UiHelper
  BUTTON_BASE = "relative inline-flex flex-none cursor-pointer items-center gap-1.5 rounded-md font-medium transition-colors".freeze

  BUTTON_SIZES = {
    sm: "px-2.5 py-1.5 text-xs",
    md: "px-3 py-2 text-sm"
  }.freeze

  def primary_button_class(size: :md)
    "#{BUTTON_BASE} #{BUTTON_SIZES.fetch(size)} bg-[#0f7082] text-white hover:bg-[#0b5d6d] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f7082]"
  end

  def secondary_button_class(size: :md)
    "#{BUTTON_BASE} #{BUTTON_SIZES.fetch(size)} border border-neutral-200 bg-white text-neutral-900 hover:bg-neutral-100"
  end

  def ghost_button_class(size: :md)
    "#{BUTTON_BASE} #{BUTTON_SIZES.fetch(size)} text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900"
  end

  def icon_button_class
    "relative cursor-pointer rounded-md p-1.5 text-neutral-500 transition-colors hover:bg-neutral-100 hover:text-neutral-900"
  end

  def primary_icon_button_class
    "relative flex cursor-pointer items-center justify-center rounded-md bg-neutral-900 p-1.5 text-white transition-colors hover:bg-neutral-800"
  end

  def field_class
    "block w-full rounded-md border border-neutral-300 bg-white px-3 py-2.5 text-sm text-neutral-950 shadow-none transition-colors placeholder:text-neutral-400 focus:border-[#0f7082] focus:outline-none focus:ring-1 focus:ring-[#0f7082]"
  end

  def field_label_class
    "mb-1.5 block text-sm font-medium text-neutral-900"
  end

  def menu_item_class
    "flex w-full cursor-pointer items-center gap-2.5 rounded-md bg-transparent px-2 py-2 text-left text-sm text-neutral-700 transition-colors hover:bg-neutral-100"
  end

  def table_cell_class
    "px-4 py-3 text-sm text-neutral-500"
  end

  def naira(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: "₦", precision: 2)
  end

  def blank_cell
    tag.span("—", class: "text-neutral-400")
  end
end
