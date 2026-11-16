require "rails_helper"

RSpec.describe "API keys" do
  let(:company_url) { "https://www.reclameaqui.com.br/empresa/assistcard/" }
  let(:params) { { engine: "reclame_aqui_company", company_id: "assistcard" } }

  before { stub_reclame_aqui(company_url, "company/assistcard.html") }

  def guest(email)
    Guest.create!(pattern: email)
    User.create!(email:)
  end

  it "answers 401 without a session or an api_key, before fetching anything" do
    get "/search.json", params: params

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]).to start_with("Invalid API key.")
    expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT)).not_to have_been_made
  end

  it "runs searches with a guest's api_key, which stays out of search_parameters and the cache" do
    ana = guest("ana@serpapi.com")
    bruno = guest("bruno@serpapi.com")

    get "/search.json", params: params.merge(api_key: ana.api_key)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["search_parameters"]).to eq("engine" => "reclame_aqui_company", "company_id" => "assistcard")
    first_id = response.parsed_body.dig("search_metadata", "id")

    get "/search.json", params: params.merge(api_key: bruno.api_key)
    expect(response.parsed_body.dig("search_metadata", "id")).to eq(first_id)

    expect(SearchRequest.order(created_at: :asc).map { |request| [ request.user.email, request.via, request.cached ] })
      .to eq([ [ "ana@serpapi.com", "api_key", false ], [ "bruno@serpapi.com", "api_key", true ] ])
  end

  it "stops accepting the key of a guest who was removed from the list" do
    user = guest("ana@serpapi.com")
    Guest.where(pattern: "ana@serpapi.com").delete

    get "/search.json", params: params.merge(api_key: user.api_key)
    expect(response).to have_http_status(:unauthorized)
  end

  it "protects the archive too" do
    get "/searches/000000000000000000000000.json"
    expect(response).to have_http_status(:unauthorized)

    get "/searches/000000000000000000000000.html"
    expect(response).to redirect_to("/sign_in")
  end
end
