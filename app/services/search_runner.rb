# Runs an engine: serves a cached search when there is one, otherwise fetches
# Reclame Aqui, parses the response and stores both.
class SearchRunner
  # Live searches spend Browser Rendering time; cached ones are free. The cap
  # keeps a public demo from draining the account.
  DAILY_LIVE_LIMIT = ENV.fetch("DAILY_LIVE_SEARCH_LIMIT", 300).to_i

  class BudgetExceeded < StandardError; end

  def initialize(client: ReclameAqui::Client.new)
    @client = client
  end

  def call(engine, no_cache: false, async: false)
    parameters = engine.search_parameters
    fingerprint = Search.fingerprint_for(parameters)
    cached = Search.cached(fingerprint) unless no_cache
    return cached.tap { |search| search.from_cache = true } if cached

    if Search.created_since(24.hours.ago).count >= DAILY_LIVE_LIMIT
      raise BudgetExceeded, "Daily live search limit reached. Searches run in the last hour are still served from cache."
    end

    search = Search.create!(engine: parameters["engine"], parameters:, fingerprint:)
    async ? SearchJob.perform_later(search.id.to_s) : perform(search)
    search
  end

  def perform(search)
    started = monotonic_ms
    engine = ReclameAqui::Engines.build(search.parameters)
    engine.prepare(@client)
    response = @client.fetch(engine.source_url)

    parse_started = monotonic_ms
    results = engine.parse(response.body)
    KnownCompany.remember(engine.companies_seen(results))
    RawResponse.create!(search:, body: response.body)

    finish(search, results:, error: results["error"], source_url: response.url, timings: {
      "fetch_ms" => response.fetch_ms,
      "browser_ms" => response.browser_ms,
      "parse_ms" => monotonic_ms - parse_started,
      "total_ms" => monotonic_ms - started
    })
  rescue ReclameAqui::NotFound => e
    finish(search, error: e.message, timings: { "total_ms" => monotonic_ms - started })
  rescue ReclameAqui::Client::FetchError, ReclameAqui::ParseError => e
    Rails.logger.error("[search #{search.id}] #{e.class}: #{e.message}")
    finish(search, status: "Error", error: e.message, timings: { "total_ms" => monotonic_ms - started })
  end

  private

  def finish(search, status: "Success", **attributes)
    search.update!(status:, processed_at: Time.current, **attributes)
    search
  end

  def monotonic_ms
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).round
  end
end
