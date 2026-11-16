module BrowserRenderingHelpers
  ENDPOINT = "https://api.cloudflare.com/client/v4/accounts/test-account/browser-rendering/content".freeze

  # Makes Browser Rendering return a fixture when asked for `url`.
  def stub_reclame_aqui(url, fixture_path, browser_ms: 1200)
    stub_request(:post, ENDPOINT)
      .with(body: hash_including("url" => url))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json", "X-Browser-Ms-Used" => browser_ms.to_s },
        body: { success: true, errors: [], result: fixture(fixture_path) }.to_json
      )
  end
end
