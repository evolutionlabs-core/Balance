class Accounting::Rules::RuleFetcher
  CACHE_KEY = "engine/rules/v1"
  CACHE_TTL = 1.minute

  def self.call(scope)
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      Rule.where(active: true).order(:id).to_a
    end.select { |rule| in_scope?(rule, scope) }
  end

  private
    def self.in_scope?(rule, scope)
      (rule.ledger_id.nil? || rule.ledger_id == scope[:ledger_id]) &&
        (rule.source_type.nil? || rule.source_type == scope[:source_type]) &&
        (rule.action.nil? || rule.action == scope[:action])
    end
    private_class_method :in_scope?
end
