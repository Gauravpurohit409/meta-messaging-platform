require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  include Devise::Test::IntegrationHelpers

  it "shows privacy and terms without signing in" do
    get privacy_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("30")
    expect(response.body).to include("180")
    expect(response.body).to include("WhatsApp")
    expect(response.body).to include("support@example.com")

    get terms_path
    expect(response).to have_http_status(:ok)
  end

  it "links privacy and terms from the public pages and the signed-in desk" do
    get root_path
    expect(response.body).to include('href="/privacy"')
    expect(response.body).to include('href="/terms"')

    get new_user_session_path
    expect(response.body).to include('href="/privacy"')
    expect(response.body).to include('href="/terms"')

    sign_in create(:user)
    get dashboard_path
    expect(response.body).to include('href="/privacy"')
    expect(response.body).to include('href="/terms"')
  end
end