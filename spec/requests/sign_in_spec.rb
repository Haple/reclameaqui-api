require "rails_helper"

RSpec.describe "Signing in" do
  before { Guest.create!(pattern: "ana@serpapi.com") }

  it "signs a guest in with a link sent by email" do
    get "/playground"
    expect(response).to redirect_to("/sign_in")

    post "/sign_in", params: { email: " Ana@SerpApi.com " }
    expect(response).to redirect_to("/sign_in/sent")
    follow_redirect!
    expect(response.body).to include("ana@serpapi.com")

    expect(last_email.to).to eq([ "ana@serpapi.com" ])
    link = last_email.text_part.body.to_s[%r{http://www\.example\.com/sign_in/link\?token=[\w-]+}]
    get link
    expect(response.body).to include("You're signing in as <strong>ana@serpapi.com</strong>")

    post "/sign_in/link", params: { token: token_from(last_email) }
    expect(response).to redirect_to("http://www.example.com/playground")
    get "/playground"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(User.find_by(email: "ana@serpapi.com").api_key)
  end

  it "answers the same for addresses that are not on the guest list, without sending anything" do
    post "/sign_in", params: { email: "someone@example.com" }

    expect(response).to redirect_to("/sign_in/sent")
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(SignInRequest.last).to have_attributes(email: "someone@example.com", admitted: false, status: "refused")
  end

  it "lets in everyone at a listed domain, and nobody at a lookalike one" do
    Guest.create!(pattern: "@serpapi.com")

    post "/sign_in", params: { email: "bruno@serpapi.com" }
    post "/sign_in", params: { email: "bruno@serpapi.com.example.net" }
    post "/sign_in", params: { email: "bruno@notserpapi.com" }

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "bruno@serpapi.com" ] ])
  end

  it "doesn't sign in when the link is only opened, so mail scanners can't spend it" do
    post "/sign_in", params: { email: "ana@serpapi.com" }
    get "/sign_in/link", params: { token: token_from(last_email) }
    get "/playground"

    expect(response).to redirect_to("/sign_in")
  end

  it "accepts each link once" do
    post "/sign_in", params: { email: "ana@serpapi.com" }
    token = token_from(last_email)
    post "/sign_in/link", params: { token: }
    delete "/sign_out"

    post "/sign_in/link", params: { token: }
    expect(response).to have_http_status(:gone)
    expect(response.body).to include("This link has expired")
  end

  it "expires links after 15 minutes" do
    post "/sign_in", params: { email: "ana@serpapi.com" }

    travel 16.minutes do
      post "/sign_in/link", params: { token: token_from(last_email) }
      expect(response).to have_http_status(:gone)
    end
  end

  it "stores only a digest of the token" do
    post "/sign_in", params: { email: "ana@serpapi.com" }
    token = token_from(last_email)

    expect(SignInRequest.last.token_digest).to eq(OpenSSL::Digest::SHA256.hexdigest(token))
    expect(SignInRequest.collection.find.to_a.to_s).not_to include(token)
  end

  it "sends an address at most three links per 15 minutes" do
    4.times { post "/sign_in", params: { email: "ana@serpapi.com" } }

    expect(ActionMailer::Base.deliveries.size).to eq(3)
  end

  it "returns to the page that asked for the sign-in" do
    get "/playground?engine=reclame_aqui&q=nubank"
    post "/sign_in", params: { email: "ana@serpapi.com" }
    post "/sign_in/link", params: { token: token_from(last_email) }

    expect(response).to redirect_to("http://www.example.com/playground?engine=reclame_aqui&q=nubank")
  end

  it "locks a guest out as soon as they are removed from the list" do
    sign_in "ana@serpapi.com"
    Guest.where(pattern: "ana@serpapi.com").delete

    get "/playground"
    expect(response).to redirect_to("/sign_in")
  end

  it "signs out" do
    sign_in "ana@serpapi.com"
    delete "/sign_out"

    expect(Session.count).to eq(0)
    get "/playground"
    expect(response).to redirect_to("/sign_in")
  end

  it "keeps the docs, the blog and the home page public" do
    %w[/ /docs /docs/reclame_aqui_company /blog/building-a-reclame-aqui-api].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
  end
end
