module Projects
  class Summary
    def initialize(project)
      @project = project
    end

    def has_budget?
      !project.cost_budget_kobo.nil?
    end

    def budget_kobo
      project.cost_budget_kobo || 0
    end

    private
      attr_reader :project
  end
end
