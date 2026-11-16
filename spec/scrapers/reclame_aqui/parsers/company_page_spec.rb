require "rails_helper"

RSpec.describe ReclameAqui::Parsers::CompanyPage do
  def parse(name)
    described_class.parse(fixture("company/#{name}.html"))
  end

  describe "an RA1000 company (assistcard)" do
    subject(:results) { parse("assistcard") }

    it "extracts the company profile" do
      expect(results[:company_info]).to include(
        id: "29260",
        company_id: "assistcard",
        name: "ASSIST CARD",
        cnpj: "00.027.571/0001-10",
        website: "http://www.assistcard.com",
        phones: [ "0800 600 2585" ],
        verified: false,
        on_reclame_aqui_since: "2011-07-07",
        time_on_reclame_aqui: "15 anos",
        page_views: 59_393,
        link: "https://www.reclameaqui.com.br/empresa/assistcard/"
      )
      expect(results[:company_info][:segment]).to include(name: "Seguradoras")
      expect(results[:company_info][:subsegments].map { |segment| segment[:name] }).to eq([ "Seguros Viagem" ])
    end

    it "reads the reputation the page displays" do
      expect(results[:reputation]).to eq(
        period: "six_months",
        label: "6 meses",
        start_date: "2026-05-01",
        end_date: "2026-10-31",
        status: "RA1000",
        status_label: "RA1000",
        score: 8.4,
        complaints: 235,
        answered: 231,
        awaiting_response: 4,
        response_rate: 98.3,
        solved_rate: 90.1,
        deal_again_rate: 71.8,
        evaluated: 140,
        consumer_score: 7.68,
        average_response_time: { seconds: 592_736, text: "6 dias e 21 horas" }
      )
    end

    it "includes the periods behind the other tabs, which the HTML never renders" do
      periods = results[:reputation_by_period]

      expect(periods.map { |period| [ period[:period], period[:label] ] }).to eq([
        %w[six_months 6\ meses], %w[twelve_months 12\ meses], %w[last_year 2025], %w[past_last_year 2024], %w[last_three_years Geral]
      ])
      expect(periods.find { |period| period[:period] == "twelve_months" }).to include(status: "GREAT", score: 8.2, complaints: 609)
    end

    it "extracts the monthly reputation history" do
      expect(results[:reputation_history].first).to eq(month: "2026-05", label: "Mai 2026", status: "GREAT", status_label: "Ótima")
      expect(results[:reputation_history].last).to include(month: "2026-10", status: "RA1000")
    end

    it "extracts the ranking, main problems, complaint preview and related companies" do
      expect(results[:ranking]).to include(position: 1, type: "best", segment: "Seguros Viagem")
      expect(results[:main_problems][:categories].first).to eq(id: "0000000000000175", name: "Seguro de Viagens", complaints: 790, percentage: 48.02)
      expect(results[:main_problems].keys).to eq(%i[categories problems products])

      expect(results[:recent_complaints].size).to eq(5)
      expect(results[:recent_complaints].first).to include(
        position: 1,
        complaint_id: "vgGSnmNfyP0knpdy",
        title: "Não recebi reembolso do seguro viagem e a seguradora não me dá resposta",
        status: "not_answered",
        status_label: "Não respondida",
        created_at: "2026-11-15T11:42:35-03:00"
      )

      expect(results[:related_companies].first).to include(
        position: 1, company_id: "mondial-assistance-seguro-viagem", name: "Allianz Travel", score: 6.1, status: "REGULAR", status_label: "Regular"
      )
    end
  end

  describe "statuses without a score" do
    it "omits the score of a 'Não recomendada' company instead of sending \"--\"" do
      reputation = parse("hotel-urbano")[:reputation]

      expect(reputation).to include(status: "NOT_RECOMMENDED", status_label: "Não recomendada", complaints: 570, response_rate: 0.0)
      expect(reputation.keys).not_to include(:score, :solved_rate, :deal_again_rate, :average_response_time)
    end

    it "handles a company without enough complaints to be rated" do
      results = parse("pagamento-digital")

      expect(results[:reputation]).to include(status: "NO_INDEX", status_label: "Sem índice")
      expect(results[:reputation_by_period].map { |period| period[:status] }).to include("NOT_RECOMMENDED")
    end

    it "reads every rated level below RA1000" do
      expect(parse("smiles")[:reputation]).to include(status: "GREAT", status_label: "Ótima")
      expect(parse("shein")[:reputation]).to include(status: "GOOD", status_label: "Boa", score: 7.5)
      expect(parse("mondial-assistance-seguro-viagem")[:reputation]).to include(status: "REGULAR", status_label: "Regular", score: 6.1)
      expect(parse("equatorial-goias")[:reputation]).to include(status: "BAD", status_label: "Ruim", score: 5.6)
    end
  end

  describe "optional sections" do
    it "reads a premium company's address, social networks and crisis alert" do
      results = parse("nubank")

      expect(results[:company_info]).to include(plan: "PREMIUM", verified: true, cnpj: "18.236.120/0001-58")
      expect(results[:company_info][:address]).to include(city: "SAO PAULO", state: "SP", gps_coordinates: { latitude: -23.5602344, longitude: -46.6735318 })
      expect(results[:company_info][:social_networks]).to include(instagram: "https://www.instagram.com/nubank/")
      expect(results[:alerts].size).to eq(1)
      expect(results[:alerts].first).to include(type: "crisis", title: "Negocição e SCR")
      expect(results[:alerts].first[:text]).to start_with("Negociação: Para negociação de valores em aberto")
    end

    it "reads a company's brands" do
      expect(parse("shein")[:brands]).to include(include(name: "FLOGISTICS"))
    end

    it "leaves out sections a company does not have" do
      expect(parse("equatorial-goias").keys).not_to include(:ranking, :alerts, :brands)
    end
  end

  it "returns an error for Reclame Aqui's 404 page" do
    expect(parse("not_found")).to eq(error: "Reclame Aqui hasn't returned any company for this company_id.")
  end

  it "fails loudly when the company island disappears" do
    html = fixture("company/assistcard.html").gsub("ContactChannelsSectionIsland", "SomethingElse")

    expect { described_class.parse(html) }.to raise_error(ReclameAqui::ParseError, /company island not found/)
  end

  # The 6 month response time is the only one rendered as text, so the others
  # are formatted by Normalize.duration_text. This checks it against the site.
  it "formats response times exactly like the site" do
    Dir[FixtureHelpers::FIXTURES.join("company/*.html")].each do |path|
      html = File.read(path)
      displayed = Nokogiri::HTML5(html).at_css('[data-company-home-section="reputation-performance"]')
        &.text&.squish&.[](/Tempo médio de resposta (.+?) Tempo médio de resposta/, 1)
      next if displayed.nil? || displayed.start_with?("--")

      expect(described_class.parse(html).dig(:reputation, :average_response_time, :text)).to eq(displayed), File.basename(path)
    end
  end
end
