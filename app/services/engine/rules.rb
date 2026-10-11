module Engine::Rules
  def self.call(command)
    scoped = RuleFetcher.call(ScopeExtractor.call(command))
    ActionRouter.call(command, scoped)
  end
end
