module ProjectsHelper
  def estimate_status_badge(estimate)
    tone = case estimate.status
    when "approved", "invoiced" then :success
    when "sent" then :warning
    when "declined" then :warning
    else :neutral
    end
    status_badge(estimate.status.humanize, tone: tone)
  end

  def project_tab_link(label, path, active)
    if active
      tag.span(label, class: "border-b-2 border-[#0f7082] px-1 pb-3 text-sm font-medium whitespace-nowrap text-neutral-950", aria: { current: "page" })
    else
      link_to(label, path, class: "px-1 pb-3 text-sm font-medium whitespace-nowrap text-neutral-500 hover:text-neutral-950")
    end
  end

  def project_activity_description(project, event)
    case event[:kind]
    when "Time"
      entry = event[:record]
      safe_join([
        tag.span("#{entry.hours}h · ", class: "tabular-nums text-neutral-500"),
        tag.span(entry.description)
      ])
    end
  end
end
