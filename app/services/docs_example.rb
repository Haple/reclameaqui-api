# Example responses for the docs and the home page, made by running the real
# parsers over the captured fixtures, so the docs cannot drift from the API.
class DocsExample
  FIXTURES = Rails.root.join("spec/fixtures/reclame_aqui")
  EXAMPLE_ID = "673a1f0c9b8e4d2a6c5f1e07".freeze

  Sample = Data.define(:params, :fixture, :source_url)

  SAMPLES = {
    "reclame_aqui" => Sample.new(
      { "q" => "nubank" }, "search/nubank.html",
      "#{ReclameAqui::Urls::IOSEARCH}/companies/search/nubank"
    ),
    "reclame_aqui_company" => Sample.new(
      { "company_id" => "nubank" }, "company/nubank.html",
      "#{ReclameAqui::Urls::SITE}/empresa/nubank/"
    ),
    "reclame_aqui_complaints" => Sample.new(
      { "company_id" => "assistcard", "filter" => "solved" }, "complaints/assistcard_solved.html",
      "#{ReclameAqui::Urls::IOSEARCH}/query/companyComplains/10/0?company=29260&evaluated=bool%3Atrue&solved=bool%3Atrue"
    ),
    "reclame_aqui_complaint" => Sample.new(
      { "company_id" => "assistcard", "complaint_id" => "SItnLCAaPpUVPgWO" }, "complaint/assistcard_solved.html",
      "#{ReclameAqui::Urls::SITE}/assistcard/_SItnLCAaPpUVPgWO/"
    )
  }.freeze

  def self.params(engine_name)
    { "engine" => engine_name }.merge(SAMPLES.fetch(engine_name).params)
  end

  def self.response(engine_name, links)
    sample = SAMPLES.fetch(engine_name)
    engine = ReclameAqui::Engines.build(params(engine_name))
    results = parsed[engine_name] ||= engine.parse(FIXTURES.join(sample.fixture).read)

    {
      "search_metadata" => {
        "id" => EXAMPLE_ID,
        "status" => "Success",
        "json_endpoint" => links.archive(EXAMPLE_ID, "json"),
        "created_at" => "2026-11-16 11:24:03 UTC",
        "processed_at" => "2026-11-16 11:24:05 UTC",
        "reclame_aqui_url" => sample.source_url,
        "raw_html_file" => links.archive(EXAMPLE_ID, "html"),
        "total_time_taken" => 1.9
      },
      "search_parameters" => engine.search_parameters
    }.merge(engine.decorate(results.deep_dup, links))
  end

  def self.parsed
    @parsed ||= {}
  end
end
