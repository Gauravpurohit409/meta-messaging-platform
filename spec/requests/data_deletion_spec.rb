require "rails_helper"

RSpec.describe "Data deletion", type: :request do
  def meta_signed_request(payload_hash, secret: "app-secret")
    payload = Base64.urlsafe_encode64(payload_hash.to_json, padding: false)
    signature = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", secret, payload), padding: false)
    "#{signature}.#{payload}"
  end

  around do |example|
    previous = ENV["META_APP_SECRET"]
    ENV["META_APP_SECRET"] = "app-secret"
    example.run
  ensure
    previous.nil? ? ENV.delete("META_APP_SECRET") : ENV["META_APP_SECRET"] = previous
  end

  it "accepts a signed request and returns a status url" do
    post webhooks_data_deletion_path, params: { signed_request: meta_signed_request({ user_id: "42", algorithm: "HMAC-SHA256" }) }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    record = DataDeletionRequest.last
    expect(record.meta_user_id).to eq("42")
    expect(body["confirmation_code"]).to eq(record.confirmation_code)
    expect(body["url"]).to include(record.confirmation_code)
  end

  it "rejects a bad signature" do
    request = meta_signed_request({ user_id: "42" })
    request[0] = request[0] == "a" ? "b" : "a"

    post webhooks_data_deletion_path, params: { signed_request: request }

    expect(response).to have_http_status(:bad_request)
    expect(DataDeletionRequest.count).to eq(0)
  end

  it "rejects a missing signed request" do
    post webhooks_data_deletion_path

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects a request when the app secret is blank" do
    ENV["META_APP_SECRET"] = ""

    post webhooks_data_deletion_path, params: { signed_request: meta_signed_request({ user_id: "42" }) }

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects malformed payloads" do
    [ "no-dot", "@@@.@@@", signed_request_broken ].each do |value|
      expect {
        post webhooks_data_deletion_path, params: { signed_request: value }
      }.not_to raise_error
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "shows the status page and hides unknown codes" do
    record = DataDeletionRequest.create!(meta_user_id: "42")

    get data_deletion_status_path(record.confirmation_code)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(record.confirmation_code)
    expect(response.body).to include("does not store a Facebook profile")

    get data_deletion_status_path("missing")
    expect(response).to have_http_status(:not_found)
  end

  it "accepts the callback without a CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post webhooks_data_deletion_path, params: { signed_request: meta_signed_request({ user_id: "42" }) }

    expect(response).to have_http_status(:ok)
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def signed_request_broken
    payload = Base64.urlsafe_encode64("not-json", padding: false)
    signature = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", "app-secret", payload), padding: false)
    "#{signature}.#{payload}"
  end
end