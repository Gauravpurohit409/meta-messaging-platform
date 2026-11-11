require "rails_helper"

RSpec.describe "Campaign A/B test", type: :request do
  include Devise::Test::IntegrationHelpers

  it "offers a second template and refuses one with different variables" do
    user = create(:user)
    version_a = create(:template, user: user, status: "approved")
    version_b = create(:template, user: user, status: "approved", body: "Your order {{1}} is ready for pickup today.")
    campaign = user.campaigns.create!(
      template: version_a,
      name: "Compare",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    campaign.recipients.create!(phone_number: "919830001111")
    sign_in user

    get campaign_path(campaign)
    expect(response.body).to include("Version B template")
    expect(response.body).to include(version_b.name)

    post launch_campaign_path(campaign), params: { variant_template_id: version_b.id }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("same variables")
    expect(campaign.reload.variant_template_id).to be_nil
  end
end
