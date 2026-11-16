require "rails_helper"

RSpec.describe ReclameAqui::Parsers::CompanySearch do
  subject(:results) { described_class.parse(json_fixture("search/nubank.html")) }

  it "lists matching companies with their reputation" do
    expect(results[:search_information]).to eq(total_results: 6)
    expect(results[:companies].first).to include(
      position: 1,
      id: "88850",
      company_id: "nubank",
      name: "Nubank",
      score: 8.8,
      status: "RA1000",
      solved_rate: 93.2,
      complaints: 56_849,
      verified: true,
      cnpj: "18.236.120/0001-58",
      location: { city: "SAO PAULO", state: "SP" },
      link: "https://www.reclameaqui.com.br/empresa/nubank/"
    )
  end

  it "omits the score of unrated companies and keeps their previous names" do
    unrated = results[:companies].find { |company| company[:company_id] == "nubank-parque-1" }

    expect(unrated).to include(status: "NO_INDEX", status_label: "Sem índice", previous_names: [ "Allianz Parque" ])
    expect(unrated.keys).not_to include(:score, :solved_rate)
  end
end
