require "rails_helper"

RSpec.describe "GET /search.json" do
  include ActiveJob::TestHelper

  let(:company_url) { "https://www.reclameaqui.com.br/empresa/assistcard/" }
  let(:complaints_url) { "https://iosearch.reclameaqui.com.br/raichu-io-site-search-v1/query/companyComplains/10/0?company=29260" }

  def search(params)
    get "/search.json", params: params
    response.parsed_body
  end

  describe "engine=reclame_aqui_company" do
    before { stub_reclame_aqui(company_url, "company/assistcard.html") }

    it "returns the company in SerpApi's response layout" do
      body = search(engine: "reclame_aqui_company", company_id: "assistcard")

      expect(response).to have_http_status(:ok)
      metadata = body["search_metadata"]
      expect(metadata["id"]).to match(/\A\h{24}\z/)
      expect(metadata).to include(
        "status" => "Success",
        "reclame_aqui_url" => company_url,
        "json_endpoint" => "http://www.example.com/searches/#{metadata['id']}.json",
        "raw_html_file" => "http://www.example.com/searches/#{metadata['id']}.html"
      )
      expect(metadata["created_at"]).to match(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d UTC\z/)
      expect(body["search_parameters"]).to eq("engine" => "reclame_aqui_company", "company_id" => "assistcard")
      expect(body["company_info"]).to include("name" => "ASSIST CARD", "id" => "29260")
      expect(body.dig("reputation", "score")).to eq(8.4)
    end

    it "links every company and complaint back into the API" do
      body = search(engine: "reclame_aqui_company", company_id: "assistcard")

      expect(body.dig("company_info", "complaints_api_link"))
        .to eq("http://www.example.com/search.json?engine=reclame_aqui_complaints&company_id=assistcard")
      expect(body["recent_complaints"].first["api_link"])
        .to eq("http://www.example.com/search.json?engine=reclame_aqui_complaint&company_id=assistcard&complaint_id=vgGSnmNfyP0knpdy")
      expect(body["related_companies"].first["api_link"])
        .to eq("http://www.example.com/search.json?engine=reclame_aqui_company&company_id=mondial-assistance-seguro-viagem")
    end

    it "serves an identical search from the last hour without fetching again" do
      first = search(engine: "reclame_aqui_company", company_id: "assistcard")
      second = search(engine: "reclame_aqui_company", company_id: "assistcard")

      expect(second.dig("search_metadata", "id")).to eq(first.dig("search_metadata", "id"))
      expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT)).to have_been_made.once
    end

    it "fetches again with no_cache=true" do
      first = search(engine: "reclame_aqui_company", company_id: "assistcard")
      second = search(engine: "reclame_aqui_company", company_id: "assistcard", no_cache: "true")

      expect(second.dig("search_metadata", "id")).not_to eq(first.dig("search_metadata", "id"))
      expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT)).to have_been_made.twice
    end

    it "returns status Processing with async=true, then the result once the job ran" do
      body = search(engine: "reclame_aqui_company", company_id: "assistcard", async: "true")
      expect(body.dig("search_metadata", "status")).to eq("Processing")
      expect(body).not_to have_key("company_info")

      perform_enqueued_jobs
      get "/searches/#{body.dig('search_metadata', 'id')}.json"
      expect(response.parsed_body.dig("search_metadata", "status")).to eq("Success")
      expect(response.parsed_body.dig("company_info", "name")).to eq("ASSIST CARD")
    end
  end

  describe "engine=reclame_aqui_complaints" do
    before do
      stub_reclame_aqui(company_url, "company/assistcard.html")
      stub_reclame_aqui(complaints_url, "complaints/assistcard_latest.html")
    end

    it "resolves the internal company id once and paginates" do
      body = search(engine: "reclame_aqui_complaints", company_id: "assistcard")

      expect(body.dig("search_information", "total_results")).to eq(4167)
      expect(body["complaints"].size).to eq(10)
      expect(body["pagination"]).to include(
        "current" => 1,
        "next" => "http://www.example.com/search.json?engine=reclame_aqui_complaints&company_id=assistcard&filter=latest&start=10&num=10"
      )
      expect(body["pagination"]["other_pages"].keys).to eq(%w[2 3])
      expect(KnownCompany.find_by(company_id: "assistcard").reclame_aqui_id).to eq("29260")

      search(engine: "reclame_aqui_complaints", company_id: "assistcard", no_cache: "true")
      expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT).with(body: hash_including("url" => company_url))).to have_been_made.once
    end

    it "rejects an unknown filter" do
      body = search(engine: "reclame_aqui_complaints", company_id: "assistcard", filter: "angry")

      expect(response).to have_http_status(:bad_request)
      expect(body["error"]).to eq("Unsupported `filter` value: angry. Use one of: latest, not_answered, answered, evaluated, solved, not_solved.")
    end
  end

  describe "errors" do
    it "requires the engine's parameters" do
      body = search(engine: "reclame_aqui_company")

      expect(response).to have_http_status(:bad_request)
      expect(body).to eq("error" => "Missing `company_id` parameter.")
    end

    it "rejects unknown engines" do
      body = search(engine: "google")

      expect(response).to have_http_status(:bad_request)
      expect(body).to eq("error" => "Unsupported `google` search engine.")
    end

    it "reports a missing company the way SerpApi reports an empty result" do
      stub_reclame_aqui("https://www.reclameaqui.com.br/empresa/esta-empresa-nao-existe-xyz123/", "company/not_found.html")
      body = search(engine: "reclame_aqui_company", company_id: "esta-empresa-nao-existe-xyz123")

      expect(response).to have_http_status(:ok)
      expect(body.dig("search_metadata", "status")).to eq("Success")
      expect(body["error"]).to eq("Reclame Aqui hasn't returned any company for this company_id.")
    end

    it "marks the search as Error when Cloudflare serves its challenge" do
      stub_request(:post, BrowserRenderingHelpers::ENDPOINT).to_return(
        status: 200, body: { success: true, result: "<html><head><title>Just a moment...</title></head></html>" }.to_json
      )
      body = search(engine: "reclame_aqui_company", company_id: "assistcard")

      expect(body.dig("search_metadata", "status")).to eq("Error")
      expect(body["error"]).to eq("Cloudflare challenge page returned for #{company_url}")
    end
  end

  describe "the archive" do
    before { stub_reclame_aqui(company_url, "company/assistcard.html") }

    let!(:search_id) { search(engine: "reclame_aqui_company", company_id: "assistcard").dig("search_metadata", "id") }

    it "serves the stored JSON" do
      get "/searches/#{search_id}.json"

      expect(response.parsed_body.dig("company_info", "company_id")).to eq("assistcard")
    end

    it "serves the raw HTML under a sandbox CSP" do
      get "/searches/#{search_id}.html"

      expect(response.media_type).to eq("text/html")
      expect(response.headers["Content-Security-Policy"]).to start_with("sandbox;")
      expect(response.body).to include("<title>ASSIST CARD - Reclame Aqui</title>")
    end

    it "serves a script-free preview for the playground" do
      get "/searches/#{search_id}/preview"

      expect(response.body).not_to include("<script")
      expect(response.body).to include('<base href="https://www.reclameaqui.com.br/">')
    end

    it "returns 404 for unknown ids" do
      get "/searches/000000000000000000000000.json"

      expect(response).to have_http_status(:not_found)
    end
  end
end
