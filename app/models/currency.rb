module Currency
  SUPPORTED = {
    "NGN" => { name: "Nigerian naira", symbol: "₦" },
    "GHS" => { name: "Ghanaian cedi", symbol: "GH₵" },
    "KES" => { name: "Kenyan shilling", symbol: "KSh" },
    "ZAR" => { name: "South African rand", symbol: "R" },
    "USD" => { name: "US dollar", symbol: "$" },
    "GBP" => { name: "British pound", symbol: "£" },
    "EUR" => { name: "Euro", symbol: "€" }
  }.freeze

  def self.codes
    SUPPORTED.keys
  end

  def self.symbol(code)
    SUPPORTED.dig(code, :symbol)
  end

  def self.label(code)
    "#{SUPPORTED.dig(code, :name)} (#{code})"
  end

  def self.options
    SUPPORTED.keys.map { |code| [ label(code), code ] }
  end

  def self.prefixes
    @prefixes ||= SUPPORTED.flat_map { |code, details| [ code, details[:symbol] ] }.sort_by { |prefix| -prefix.length }.freeze
  end
end
