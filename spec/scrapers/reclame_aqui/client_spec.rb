require "rails_helper"

RSpec.describe ReclameAqui::Client do
  subject(:client) { described_class.new(account_id: "test-account", api_token: "test-token") }

  let(:url) { "https://www.reclameaqui.com.br/empresa/assistcard/" }

  before { allow(client).to receive(:sleep) }

  it "asks Browser Rendering for the page without images, fonts or media" do
    stub_reclame_aqui(url, "company/assistcard.html", browser_ms: 963)
    response = client.fetch(url)

    expect(response.body).to include("ASSIST CARD")
    expect(response.browser_ms).to eq(963)
    expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT).with(
      headers: { "Authorization" => "Bearer test-token" },
      body: hash_including("url" => url, "rejectResourceTypes" => %w[image media font])
    )).to have_been_made
  end

  it "retries when Browser Rendering is rate limited" do
    stub_request(:post, BrowserRenderingHelpers::ENDPOINT)
      .to_return({ status: 429, headers: { "Retry-After" => "2" }, body: { success: false }.to_json },
                 { status: 200, body: { success: true, result: "<title>ok</title>" }.to_json })

    expect(client.fetch(url).body).to eq("<title>ok</title>")
    expect(client).to have_received(:sleep).with(2)
  end

  it "reports Cloudflare API errors" do
    stub_request(:post, BrowserRenderingHelpers::ENDPOINT)
      .to_return(status: 401, body: { success: false, errors: [ { code: 10_000, message: "Authentication error" } ] }.to_json)

    expect { client.fetch(url) }.to raise_error(described_class::FetchError, "Browser Rendering returned HTTP 401: Authentication error")
  end

  it "treats Cloudflare's challenge page as a failure" do
    stub_request(:post, BrowserRenderingHelpers::ENDPOINT)
      .to_return(status: 200, body: { success: true, result: "<html><head><title>Um momento…</title>" }.to_json)

    expect { client.fetch(url) }.to raise_error(described_class::FetchError, /challenge page/)
  end

  it "gives up after repeated timeouts" do
    stub_request(:post, BrowserRenderingHelpers::ENDPOINT).to_timeout

    expect { client.fetch(url) }.to raise_error(described_class::FetchError, /Net::OpenTimeout/)
    expect(a_request(:post, BrowserRenderingHelpers::ENDPOINT)).to have_been_made.times(3)
  end
end
