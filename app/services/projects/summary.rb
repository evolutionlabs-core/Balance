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

    def estimate_value_kobo
      project.estimates.where.not(status: :declined).sum(:total_minor)
    end

    def invoice_value_kobo
      project.invoices.sum(:total_minor)
    end

    def amount_owed_kobo
      project.invoices.posted.includes(:receivable_applications).sum(&:balance_due_kobo)
    end

    def amount_received_kobo
      project.invoices.posted.includes(:receivable_applications).sum(&:applied_amount_kobo)
    end

    private
      attr_reader :project
  end
end
