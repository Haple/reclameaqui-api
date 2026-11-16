require "rails_helper"

RSpec.describe ReclameAqui::AstroProps do
  it "decodes Astro's [type, value] tuples" do
    raw = {
      name: [ 0, "ASSIST CARD" ],
      count: [ 0, 235 ],
      missing: [ 0 ],
      tags: [ 1, [ [ 0, "a" ], [ 0, { id: [ 0, "1" ] } ] ] ],
      lookup: [ 4, [ [ 1, [ [ 0, "k" ], [ 0, "v" ] ] ] ] ],
      big: [ 6, "9007199254740993" ],
      forever: [ 11, 1 ]
    }.to_json

    expect(described_class.parse(raw)).to eq(
      "name" => "ASSIST CARD",
      "count" => 235,
      "missing" => nil,
      "tags" => [ "a", { "id" => "1" } ],
      "lookup" => { "k" => "v" },
      "big" => 9_007_199_254_740_993,
      "forever" => Float::INFINITY
    )
  end

  it "decodes a real island" do
    page = ReclameAqui::Page.new(fixture("company/assistcard.html"))

    expect(page.island("PeopleAlsoVisitedIsland")["relatedCompanies"].first).to include("shortname" => "mondial-assistance-seguro-viagem")
    expect(page.islands.map { |island| island[:component] }).to include("ContactChannelsSectionIsland", "RankingIsland")
  end
end
