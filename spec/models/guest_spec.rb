require "rails_helper"

RSpec.describe Guest do
  describe ".admits?" do
    before do
      described_class.create!(pattern: "Ana@Example.com")
      described_class.create!(pattern: "@serpapi.com")
    end

    it "matches addresses regardless of case and spaces" do
      expect(described_class.admits?(" ana@example.COM")).to be true
    end

    it "matches everyone at a listed domain" do
      expect(described_class.admits?("bruno@serpapi.com")).to be true
    end

    it "doesn't match subdomains, lookalikes or other people at a listed address's domain" do
      expect(described_class.admits?("bruno@mail.serpapi.com")).to be false
      expect(described_class.admits?("bruno@serpapi.com.evil.test")).to be false
      expect(described_class.admits?("bruno@example.com")).to be false
    end

    it "never matches a domain on its own or something that isn't an address" do
      expect(described_class.admits?("@serpapi.com")).to be false
      expect(described_class.admits?("serpapi.com")).to be false
      expect(described_class.admits?(nil)).to be false
    end
  end

  it "rejects entries that are neither an address nor a domain" do
    expect(described_class.new(pattern: "serpapi.com")).not_to be_valid
    expect(described_class.new(pattern: "a@b@serpapi.com")).not_to be_valid
  end
end
