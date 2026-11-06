require "rails_helper"

RSpec.describe "Connection page", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:account) { user.whatsapp_account }

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

  before { sign_in user }

  it "keeps manual credentials available in demo mode and hides the verify token" do
    get settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("System user token")
    expect(response.body).to include("Demo mode")
    expect(response.body).not_to include("Verify token")
    expect(response.body).not_to include(account.verify_token)
    expect(response.body).not_to include("Connect with Meta")
  end

  it "saves a pasted token while demo mode stays on" do
    patch settings_path, params: {
      whatsapp_account: {
        demo_mode: "1",
        waba_id: "111",
        phone_number_id: "222",
        display_phone: "+1 555 0100",
        access_token: "demo-token"
      }
    }

    expect(response).to redirect_to(settings_path)
    expect(account.reload.demo_mode).to be(true)
    expect(account.access_token).to eq("demo-token")
    expect(account.display_phone).to eq("+1 555 0100")
  end

  it "refuses to go live by pasting a token" do
    patch settings_path, params: {
      whatsapp_account: { demo_mode: "0", waba_id: "111", phone_number_id: "222", access_token: "pasted" }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Embedded Signup")
    expect(account.reload.demo_mode).to be(true)
    expect(account.access_token).not_to eq("pasted")
  end

  it "offers Embedded Signup instead of a token field when the desk is live" do
    account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "tok")

    get settings_path

    expect(response.body).to include("Connect with Meta")
    expect(response.body).to include('data-embedded-signup-app-id-value="1234567890"')
    expect(response.body).to include('data-embedded-signup-config-id-value="987654321"')
    expect(response.body).not_to include("System user token")
    expect(response.body).not_to include("Verify token")
  end

  it "explains that Embedded Signup is not configured" do
    ENV["META_APP_ID"] = ""
    account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "tok")

    get settings_path

    expect(response.body).to include("Embedded Signup is not configured")
    expect(response.body).not_to include("System user token")
    expect(response.body).not_to include("Connect with Meta")
  end

  it "removes the per-desk verify token action" do
    expect { post "/settings/regenerate_verify_token" }.to raise_error(ActionController::RoutingError)
  end

  it "documents Embedded Signup instead of a pasted verify token" do
    readme = Rails.root.join("README.md").read

    expect(readme).to include("Embedded Signup")
    expect(readme).to include("META_EMBEDDED_SIGNUP_CONFIG_ID")
    expect(readme).not_to include("paste the verify token")
    expect(readme).not_to include("save the WABA id, phone number id, and token")
  end

  it "starts Embedded Signup from the connection page script" do
    source = Rails.root.join("app/javascript/controllers/embedded_signup_controller.js").read

    expect(source).to include("FB.login")
    expect(source).to include("config_id")
    expect(source).to include("response_type")
    expect(source).to include("sessionInfoVersion")
    expect(source).to include("WA_EMBEDDED_SIGNUP")
    expect(source).to include("waba_id")
    expect(source).to include("phone_number_id")
    expect(source).to include("/settings/embedded_signup")
  end
end
