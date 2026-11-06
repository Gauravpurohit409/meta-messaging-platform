require "rails_helper"

RSpec.describe "Embedded signup", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  around do |example|
    keys = %w[META_APP_ID META_EMBEDDED_SIGNUP_CONFIG_ID META_APP_SECRET]
    saved = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["META_APP_ID"] = "1234567890"
    ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"
    ENV["META_APP_SECRET"] = "app-secret"
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  it "requires a signed-in desk" do
    post "/settings/embedded_signup", params: valid_signup

    expect(response).to redirect_to(new_user_session_path)
  end

  it "connects the signed-in desk and ignores a posted account id" do
    sign_in user
    other = create(:user)
    allow(Meta::EmbeddedSignup).to receive(:connect).and_return(true)

    post "/settings/embedded_signup", params: valid_signup.merge(account_id: other.whatsapp_account.id)

    expect(response).to redirect_to(settings_path)
    expect(flash[:notice]).to match(/connected/i)
    expect(Meta::EmbeddedSignup).to have_received(:connect).with(
      account: user.whatsapp_account,
      code: "good_CODE-1",
      waba_id: "111",
      phone_number_id: "222"
    )
    expect(other.whatsapp_account.reload.access_token).to be_nil
  end

  it "shows Meta's reason when the connection fails" do
    sign_in user
    allow(Meta::EmbeddedSignup).to receive(:connect) do |account:, **|
      account.errors.add(:base, "Invalid code")
      false
    end

    post "/settings/embedded_signup", params: valid_signup

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Invalid code")
  end

  it "rejects a malformed signup before calling Meta" do
    sign_in user
    allow(Meta::EmbeddedSignup).to receive(:connect)

    post "/settings/embedded_signup", params: valid_signup.merge(code: "bad code")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Meta::EmbeddedSignup).not_to have_received(:connect)
  end

  it "refuses to start when Embedded Signup is not configured" do
    sign_in user
    ENV["META_APP_ID"] = ""
    allow(Meta::EmbeddedSignup).to receive(:connect)

    post "/settings/embedded_signup", params: valid_signup

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("not configured")
    expect(Meta::EmbeddedSignup).not_to have_received(:connect)
  end

  it "rejects a signup posted without the authenticity token" do
    sign_in user
    ActionController::Base.allow_forgery_protection = true

    post "/settings/embedded_signup", params: valid_signup

    expect(response).to have_http_status(:unprocessable_entity)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "accepts a signup that includes the authenticity token from the connection page" do
    sign_in user
    ActionController::Base.allow_forgery_protection = true
    get settings_path
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    allow(Meta::EmbeddedSignup).to receive(:connect).and_return(true)

    post "/settings/embedded_signup", params: valid_signup.merge(authenticity_token: token)

    expect(response).to redirect_to(settings_path)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "disconnects the signed-in desk" do
    sign_in user
    allow(Meta::EmbeddedSignup).to receive(:disconnect).and_return(true)

    delete "/settings/embedded_signup"

    expect(response).to redirect_to(settings_path)
    expect(flash[:notice]).to match(/disconnected/i)
    expect(Meta::EmbeddedSignup).to have_received(:disconnect).with(account: user.whatsapp_account)
  end

  it "shows Meta's reason when the unsubscribe fails and the desk is still signed out of Meta" do
    sign_in user
    allow(Meta::EmbeddedSignup).to receive(:disconnect) do |account:|
      account.errors.add(:base, "unavailable")
      false
    end

    delete "/settings/embedded_signup"

    expect(response).to redirect_to(settings_path)
    expect(flash[:alert]).to include("unavailable")
  end

  def valid_signup
    { code: "good_CODE-1", waba_id: "111", phone_number_id: "222" }
  end
end
