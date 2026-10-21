module ChartCatalog
  PATH = Rails.root.join("app/models/chart_catalog.yml")

  TEMPLATES = {
    "business" => { "goods" => "Goods and services", "services" => "Services only" },
    "personal" => { "standard" => "Standard" }
  }.freeze

  def self.templates_for(workspace_type)
    TEMPLATES.fetch(workspace_type.to_s)
  end

  def self.default_template(workspace_type)
    templates_for(workspace_type).keys.first
  end

  def self.accounts_for(workspace_type, template: nil)
    profile = workspace_type.to_s
    template ||= default_template(profile)
    raise ArgumentError, "Unknown #{profile} chart template: #{template}" unless templates_for(profile).key?(template)

    entries.select { |entry| entry["profiles"].include?(profile) && entry.fetch("templates", [ template ]).include?(template) }.map do |entry|
      {
        key: entry["key"],
        code: entry.dig("codes", profile) || entry["code"],
        name: entry.dig("names", profile) || entry["name"],
        base_type: entry["base_type"],
        subtype: entry["subtype"],
        system: entry.fetch("system", false)
      }
    end
  end

  def self.entries
    @entries ||= YAML.load_file(PATH).fetch("accounts").freeze
  end
  private_class_method :entries
end
