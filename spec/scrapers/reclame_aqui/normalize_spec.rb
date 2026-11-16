require "rails_helper"

RSpec.describe ReclameAqui::Normalize do
  describe ".number" do
    it "reads the site's number formats" do
      expect(described_class.number("8.4")).to eq(8.4)
      expect(described_class.number("98,3%")).to eq(98.3)
      expect(described_class.number("235")).to eq(235)
      expect(described_class.number(7.68)).to eq(7.68)
    end

    it "treats the site's placeholders as missing" do
      expect([ "--", "", nil, "-- dado não disponível" ].map { |value| described_class.number(value) }).to all(be_nil)
    end
  end

  describe ".time" do
    it "reads bare and Z-suffixed timestamps as Brasília time" do
      expect(described_class.time("2026-11-16T06:54:04")).to eq("2026-11-16T06:54:04-03:00")
      expect(described_class.time("2026-11-15T11:42:35.000Z")).to eq("2026-11-15T11:42:35-03:00")
      expect(described_class.time("")).to be_nil
    end
  end

  it "formats CNPJs" do
    expect(described_class.cnpj("00027571000110")).to eq("00.027.571/0001-10")
    expect(described_class.cnpj("123")).to be_nil
  end

  it "converts month labels" do
    expect(described_class.month("Mai 2026")).to eq("2026-05")
    expect(described_class.month("Dez 2025")).to eq("2025-12")
  end

  describe ".duration_text" do
    it "rounds to the hour and uses singular forms like the site" do
      expect(described_class.duration_text(592_736.0086)).to eq("6 dias e 21 horas")
      expect(described_class.duration_text(521_038.958)).to eq("6 dias e 1 hora")
      expect(described_class.duration_text(86_400 + 3_600 * 23.6)).to eq("2 dias")
      expect(described_class.duration_text(7_200)).to eq("2 horas")
      expect(described_class.duration_text("--")).to be_nil
    end
  end

  it "derives the complaint badge from the evaluation flags" do
    expect(described_class.complaint_status("PENDING", evaluated: false, solved: false)).to eq([ "not_answered", "Não respondida" ])
    expect(described_class.complaint_status("ANSWERED", evaluated: false, solved: false)).to eq(%w[answered Respondida])
    expect(described_class.complaint_status("ANSWERED", evaluated: true, solved: true)).to eq(%w[solved Resolvido])
    expect(described_class.complaint_status("SOLVED", evaluated: true, solved: false)).to eq([ "not_solved", "Não resolvido" ])
  end

  it "turns HTML into plain text" do
    expect(described_class.text("<p><strong>A:</strong> b</p><p>c</p>")).to eq("A: b\n\nc")
    expect(described_class.text("x<br /><br />y &amp; z")).to eq("x\n\ny & z")
  end

  it "drops missing keys but keeps false and zero" do
    expect(described_class.prune(a: nil, b: false, c: 0, d: [], e: {}, f: "")).to eq(b: false, c: 0)
  end
end
