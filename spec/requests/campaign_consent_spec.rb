require "rails_helper"

RSpec.describe "Campaign consent", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:template) { create(:template, user: user, status: "approved") }

  before { sign_in user }

  def post_campaign(extra = {})
    post campaigns_path, params: {
      campaign: { name: "Pickup", template_id: template.id },
      audience_text: "919830001111\n919830002222"
    }.merge(extra)
  end

  it "requires the opt-in confirmation" do
    post_campaign(consent_source_note: "Checkout form")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Confirm that everyone on the list opted in")
    expect(user.campaigns.count).to eq(0)
  end

  it "requires a note about where the opt-in was collected" do
    post_campaign(consent_confirmed: "1", consent_source_note: "  ")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Say where the opt-in was collected")
  end

  it "stores one consent per recipient" do
    post_campaign(consent_confirmed: "1", consent_source_note: "Checkout form")

    expect(response).to redirect_to(user.campaigns.last)
    expect(Consent.where(user: user).order(:phone_number).pluck(:phone_number, :source, :wording)).to eq([
      [ "919830001111", "campaign_upload", "Checkout form" ],
      [ "919830002222", "campaign_upload", "Checkout form" ]
    ])
  end

  it "does not re-activate a revoked number" do
    Consent.revoke!(user: user, phone_number: "919830001111", reason: "stop")

    post_campaign(consent_confirmed: "1", consent_source_note: "Checkout form")

    expect(Consent.find_by(user: user, phone_number: "919830001111").revoked_at).to be_present
  end
end
