require "rails_helper"

RSpec.describe ReclameAqui::Parsers::ComplaintPage do
  def parse(name)
    described_class.parse(fixture("complaint/#{name}.html"))
  end

  describe "a solved complaint" do
    subject(:results) { parse("assistcard_solved") }

    it "extracts the complaint and the consumer's evaluation" do
      expect(results[:complaint]).to include(
        complaint_id: "SItnLCAaPpUVPgWO",
        title: "Não recebi o reembolso do meu seguro viagem após 90 dias",
        status: "solved",
        status_label: "Resolvido",
        rating: 10.0,
        deal_again: true,
        location: { city: "São Paulo", state: "SP" },
        category: { id: "0000000000000175", name: "Seguro de Viagens" },
        problem: { id: "0000000000000128", name: "Reembolso" },
        product: { name: "Seguro de viagem" }
      )
    end

    # The page stamps local time with a "Z". Read as UTC it would put the
    # complaint three hours later than the site's own "Há 20h" labels.
    it "reads the mislabeled Z timestamps as Brasília time" do
      expect(results[:complaint][:created_at]).to eq("2026-11-05T10:15:17-03:00")
    end

    it "turns the conversation into plain text, oldest first" do
      expect(results[:interactions].map { |interaction| interaction[:type] }).to eq(%w[company_answer final_consideration])
      expect(results[:interactions].first[:message]).to start_with("Prezada Renata,\n\nAgradecemos")
      expect(results[:interactions].first[:message]).not_to include("<br")
      expect(results[:interactions].last).to eq(type: "final_consideration", message: "Tudo foi resolvido", created_at: "2026-11-09T11:08:59-03:00")
    end

    it "reads the company's reputation out of the Java Map#toString() it ships as" do
      expect(results[:company]).to include(company_id: "assistcard", name: "ASSIST CARD")
      expect(results[:company][:reputation]).to eq(period: "six_months", status: "RA1000", status_label: "RA1000", score: 8.4, solved_rate: 90.1)
      expect(results[:company][:ranking]).to include(position: 1, type: "best")
    end
  end

  describe "an unanswered complaint" do
    subject(:results) { parse("assistcard_pending") }

    it "has no evaluation and no conversation yet" do
      expect(results[:complaint]).to include(status: "not_answered", evaluated: false)
      expect(results[:complaint].keys).not_to include(:rating, :deal_again)
      expect(results).not_to have_key(:interactions)
    end

    it "lists similar complaints" do
      expect(results[:similar_complaints].size).to eq(4)
      expect(results[:similar_complaints].first).to include(position: 1, complaint_id: "1pXCLDwa_84X3v0H", status: "not_answered")
    end
  end

  it "returns an error for Reclame Aqui's 404 page" do
    expect(described_class.parse(fixture("company/not_found.html"))).to eq(error: described_class::NOT_FOUND)
  end
end
