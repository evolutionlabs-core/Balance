class FeedbackReport
  include ActiveModel::Model
  include ActiveModel::Attributes

  KINDS = { "bug" => "Bug", "idea" => "Idea" }.freeze
  LABELS = { "bug" => "bug", "idea" => "enhancement" }.freeze

  attribute :kind, :string, default: "bug"
  attribute :description, :string
  attribute :page, :string
  attribute :browser, :string

  attr_accessor :reporter

  validates :kind, inclusion: { in: KINDS.keys }
  validates :description, presence: { message: "can't be empty. Tell us what happened." }, length: { maximum: 5_000 }

  def self.enabled?
    GithubIssue.configured?
  end

  def submit
    return false unless valid?

    GithubIssue.create(title: title, body: body, labels: [ LABELS.fetch(kind) ])
  rescue GithubIssue::Error
    errors.add(:base, "We couldn't send that just now. Please try again in a moment.")
    false
  end

  def title
    summary = description.to_s.strip.lines.first.to_s.strip.truncate(80, separator: " ")
    "#{KINDS.fetch(kind)}: #{summary}"
  end

  def body
    <<~MARKDOWN
      #{description.to_s.strip}

      ---
      | | |
      |---|---|
      | Page | `#{page_path}` |
      | Reported by | #{reporter_name} |
      | Browser | #{browser.to_s.truncate(200)} |
      | Version | #{revision} (#{Rails.env}) |

      _Sent from the in-app feedback form._
    MARKDOWN
  end

  private
    def page_path
      path = URI.parse(page.to_s).path.presence
      path || "unknown"
    rescue URI::InvalidURIError
      "unknown"
    end

    def revision
      ENV.values_at("RAILWAY_GIT_COMMIT_SHA", "GIT_REVISION").compact.first&.first(7) || "unknown"
    end

    def reporter_name
      first, *rest = reporter&.full_name.to_s.split
      return "unknown" if first.blank?

      [ first, rest.last&.first&.then { |initial| "#{initial}." } ].compact.join(" ")
    end
end
