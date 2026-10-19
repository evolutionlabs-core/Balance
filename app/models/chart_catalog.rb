module ChartCatalog
  PATH = Rails.root.join("app/models/chart_catalog.yml")

  def self.accounts_for(workspace_type)
    profile = workspace_type.to_s

    entries.select { |entry| entry["profiles"].include?(profile) }.map do |entry|
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
