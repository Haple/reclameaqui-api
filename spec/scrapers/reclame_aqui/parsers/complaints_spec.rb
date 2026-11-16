require "rails_helper"

RSpec.describe ReclameAqui::Parsers::Complaints do
  def parse(name, start: 0)
    described_class.parse(json_fixture("complaints/#{name}.html"), start:)
  end

  it "extracts the latest complaints" do
    results = parse("assistcard_latest")

    expect(results[:search_information]).to eq(total_results: 4167)
    expect(results[:complaints].map { |complaint| complaint[:position] }).to eq((1..10).to_a)
    expect(results[:complaints].first).to include(
      complaint_id: "1pXCLDwa_84X3v0H",
      title: "Contratei seguro da Latam e não tenho direito a assistência por desvio de bagagem",
      status: "not_answered",
      status_label: "Não respondida",
      solved: false,
      evaluated: false,
      created_at: "2026-11-16T06:54:04-03:00",
      location: { city: "Campina Grande", state: "PB" },
      company: { id: "29260", company_id: "assistcard", name: "ASSIST CARD" },
      link: "https://www.reclameaqui.com.br/assistcard/contratei-seguro-da-latam-e-nao-tenho-direito-a-assistencia-por-desvio-de-bagagem_1pXCLDwa_84X3v0H/"
    )
    expect(results[:complaints].first.keys).not_to include(:rating, :deal_again)
  end

  it "numbers positions from the requested offset" do
    expect(parse("assistcard_not_answered_start10", start: 10)[:complaints].first[:position]).to eq(11)
  end

  it "reads the consumer's evaluation of solved complaints" do
    complaint = parse("assistcard_solved")[:complaints].first

    expect(complaint).to include(status: "solved", status_label: "Resolvido", rating: 10.0, deal_again: true)
  end

  it "returns the facets the site's filter sidebar offers" do
    filters = parse("assistcard_latest")[:filters]

    expect(filters.keys).to eq(%i[categories products problems])
    expect(filters[:categories].first).to eq(id: "0000000000000175", name: "Seguro de Viagens", complaints: 1938)
  end

  it "uses the masked text, which keyword searches return in full" do
    snippet = parse("assistcard_q_reembolso")[:complaints].first[:snippet]

    expect(snippet.length).to be > 130
    expect(snippet.length).to be <= described_class::SNIPPET_LENGTH
    expect(snippet).not_to include("<br")
  end

  it "fails loudly on an unexpected payload" do
    expect { described_class.parse({ "companies" => [] }) }.to raise_error(ReclameAqui::ParseError)
  end
end
