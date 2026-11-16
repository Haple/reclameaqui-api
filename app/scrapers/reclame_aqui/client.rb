require "net/http"

module ReclameAqui
  # Fetches Reclame Aqui through Cloudflare Browser Rendering, a headless Chrome
  # running on Cloudflare's network.
  #
  # Reclame Aqui sits behind Cloudflare's bot challenge. From a datacenter IP,
  # curl and a local headless Chromium both get the "Um momento..." page (403).
  # Browser Rendering requests are signed and identify themselves as automated,
  # and the site lets them through, so nothing here tries to look like a human.
  class Client
    ENDPOINT = "https://api.cloudflare.com/client/v4/accounts/%s/browser-rendering/content".freeze
    CHALLENGE_TITLE = %r{<title>\s*(Just a moment|Um momento)}i
    RETRYABLE = [ 429, 500, 502, 503, 504 ].freeze
    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, OpenSSL::SSL::SSLError ].freeze

    Response = Data.define(:url, :body, :browser_ms, :fetch_ms)

    class FetchError < StandardError; end

    def initialize(account_id: ENV["CLOUDFLARE_ACCOUNT_ID"], api_token: ENV["CLOUDFLARE_API_TOKEN"], attempts: 3, timeout: 60)
      @account_id = account_id
      @api_token = api_token
      @attempts = attempts
      @timeout = timeout
    end

    def fetch(url)
      raise FetchError, "CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN are not set" if @account_id.blank? || @api_token.blank?

      started = monotonic_ms
      1.upto(@attempts) do |attempt|
        response = post(url)
        if RETRYABLE.include?(response.code.to_i) && attempt < @attempts
          sleep(backoff(attempt, response["Retry-After"]))
          next
        end
        return build_response(url, response, started)
      rescue *NETWORK_ERRORS => e
        raise FetchError, "#{e.class}: #{e.message}" if attempt == @attempts

        sleep(backoff(attempt))
      end
    end

    private

    # Images, fonts and media are never parsed, and skipping them cuts the
    # browser time billed per page. The data is server rendered, so the DOM is
    # complete at DOMContentLoaded.
    def post(url)
      uri = URI(format(ENDPOINT, @account_id))
      request = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{@api_token}", "Content-Type" => "application/json")
      request.body = {
        url:,
        rejectResourceTypes: %w[image media font],
        gotoOptions: { waitUntil: "domcontentloaded", timeout: 45_000 }
      }.to_json

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: @timeout) do |http|
        http.request(request)
      end
    end

    def build_response(url, response, started)
      payload = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        {}
      end
      raise FetchError, failure_message(response, payload) unless response.is_a?(Net::HTTPSuccess) && payload["success"]

      body = payload["result"].to_s
      raise FetchError, "Cloudflare challenge page returned for #{url}" if body.match?(CHALLENGE_TITLE)

      Response.new(url:, body:, browser_ms: response["X-Browser-Ms-Used"].to_i, fetch_ms: monotonic_ms - started)
    end

    def failure_message(response, payload)
      errors = Array(payload["errors"]).map { |error| error["message"] }.join(", ")
      "Browser Rendering returned HTTP #{response.code}#{": #{errors}" if errors.present?}"
    end

    def backoff(attempt, retry_after = nil)
      retry_after.to_i.positive? ? [ retry_after.to_i, 10 ].min : 0.5 * (2**(attempt - 1))
    end

    def monotonic_ms
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).round
    end
  end
end
