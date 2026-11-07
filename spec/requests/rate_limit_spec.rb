require "rails_helper"

RSpec.describe "Rate limits", type: :request do
  around do |example|
    previous = Rack::Attack.enabled
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.enabled = previous
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  it "limits sign-in attempts from one address" do
    10.times do
      post "/users/sign_in", params: { user: { email: "a@marquee.test", password: "nope" } }
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post "/users/sign_in", params: { user: { email: "a@marquee.test", password: "nope" } }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to be_present
  end

  it "limits sign-up and password resets" do
    5.times { post "/users", params: { user: { email: "new@marquee.test", password: "password123" } } }
    post "/users", params: { user: { email: "newer@marquee.test", password: "password123" } }
    expect(response).to have_http_status(:too_many_requests)

    Rack::Attack.cache.store.clear
    5.times { post "/users/password", params: { user: { email: "a@marquee.test" } } }
    post "/users/password", params: { user: { email: "a@marquee.test" } }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "limits embedded signup posts" do
    10.times { post "/settings/embedded_signup", params: { code: "x", waba_id: "1", phone_number_id: "2" } }
    post "/settings/embedded_signup", params: { code: "x", waba_id: "1", phone_number_id: "2" }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "does not limit the webhook" do
    30.times do
      get "/webhooks/meta"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "counts a different address separately" do
    10.times { post "/users/sign_in", params: { user: { email: "a@marquee.test", password: "nope" } } }
    post "/users/sign_in", params: { user: { email: "a@marquee.test", password: "nope" } }, headers: { "REMOTE_ADDR" => "10.0.0.2" }
    expect(response).not_to have_http_status(:too_many_requests)
  end
end