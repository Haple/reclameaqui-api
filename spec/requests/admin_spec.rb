require "rails_helper"

RSpec.describe "GET /admin" do
  it "shows the guest list, who tried to sign in and what guests searched" do
    stub_reclame_aqui("https://www.reclameaqui.com.br/empresa/assistcard/", "company/assistcard.html")
    Guest.create!(pattern: "@serpapi.com")
    sign_in "bruno@serpapi.com"
    get "/search.json", params: { engine: "reclame_aqui_company", company_id: "assistcard" }
    get "/search.json", params: { engine: "reclame_aqui_company", company_id: "assistcard" }
    delete "/sign_out"
    post "/sign_in", params: { email: "stranger@example.com" }

    sign_in "aleph@example.com", admin: true
    get "/admin"

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML5(response.body)
    people = page.css("section:nth-of-type(2) tbody tr").map { |row| row.css("td").map(&:text).map(&:strip) }
    expect(people).to include(a_collection_including("bruno@serpapi.com", "2", "yes"))
    expect(page.text).to include("stranger@example.com")
    expect(page.css("section:nth-of-type(3) .badge").map(&:text)).to include("refused", "used")
    expect(page.css("section:nth-of-type(4) td").map(&:text).join).to include("cached")
  end

  it "is not found for guests who aren't admins" do
    sign_in "bruno@serpapi.com"
    get "/admin"

    expect(response).to have_http_status(:not_found)
  end

  it "only takes admin on a full address" do
    expect(Guest.new(pattern: "@serpapi.com", admin: true)).not_to be_valid
  end
end
