require "net/http"

class Beerus
  class Error < StandardError; end

  class << self
    def connect_script_url
      "#{ENV.fetch("BEERUS_CONNECT_URL", "http://connect.localhost:7444")}/connect.js"
    end

    def create_link_token(user_id:, redirect_uri:)
      request(:post, "/v1/link/token/create", body: { user_id: user_id, redirect_uri: redirect_uri }).fetch("link_token")
    end

    def exchange_public_token(public_token)
      request(:post, "/v1/public_token/exchange", body: { public_token: public_token }).fetch("access_token")
    end

    def posted_transactions(access_token)
      accounts(access_token)
        .flat_map { |account| transactions(access_token, account.fetch("id")) }
        .select { |line| line.fetch("status") == "posted" }
        .sort_by { |line| [ line.fetch("booked_at"), line.fetch("sequence") ] }
        .reverse
    end

    def refresh(access_token)
      accounts(access_token).each do |account|
        request(:post, "/v1/accounts/#{account.fetch("id")}/refresh", access_token: access_token)
      end
    end

    private
      def accounts(access_token)
        request(:get, "/v1/accounts", access_token: access_token).fetch("data")
      end

      def transactions(access_token, account_id)
        lines = {}
        cursor = nil

        loop do
          page = request(:get, "/v1/accounts/#{account_id}/transactions/sync", access_token: access_token, query: { cursor: cursor }.compact)
          (page.fetch("added") + page.fetch("modified")).each { |line| lines[line.fetch("id")] = line }
          page.fetch("removed").each { |line| lines.delete(line.fetch("id")) }
          cursor = page.fetch("next_cursor")
          break unless page.fetch("has_more")
        end

        lines.values
      end

      def request(method, path, body: nil, query: {}, access_token: nil)
        uri = URI("#{api_url}#{path}")
        uri.query = URI.encode_www_form(query) if query.any?

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do |http|
          http.request(build_request(method, uri, body, access_token))
        end

        raise Error, "Beerus responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError, KeyError => error
        raise Error, error.message
      end

      def build_request(method, uri, body, access_token)
        request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
        request["Beerus-Client-ID"] = ENV.fetch("BEERUS_CLIENT_ID")
        request["Beerus-Secret"] = ENV.fetch("BEERUS_SECRET")
        request["Beerus-Access-Token"] = access_token if access_token

        if method == :post
          request["Idempotency-Key"] = SecureRandom.uuid
          request.content_type = "application/json"
          request.body = (body || {}).to_json
        end

        request
      end

      def api_url
        ENV.fetch("BEERUS_API_URL", "http://connect.localhost:7443")
      end
  end
end
