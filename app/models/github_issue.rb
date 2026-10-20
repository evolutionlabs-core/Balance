require "net/http"

class GithubIssue
  class Error < StandardError; end

  API = "https://api.github.com".freeze

  def self.configured?
    token.present?
  end

  def self.create(title:, body:, labels: [])
    uri = URI("#{API}/repos/#{repository}/issues")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = "2022-11-28"
    request.content_type = "application/json"
    request.body = { title: title, body: body, labels: labels }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end

    raise Error, "GitHub responded #{response.code}" unless response.is_a?(Net::HTTPCreated)

    JSON.parse(response.body).fetch("html_url")
  rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError, KeyError => error
    raise Error, error.message
  end

  def self.token
    ENV["GITHUB_FEEDBACK_TOKEN"]
  end

  def self.repository
    ENV.fetch("GITHUB_FEEDBACK_REPO", "evolutionlabs-core/Balance")
  end
end
