require "rails_helper"

RSpec.describe "Campaign analytics", type: :request do
  include Devise::Test::IntegrationHelpers

  it "shows the estimated delivery cost and a high-failure notice" do
    user = create(:user)
    template = create(:template, user: user, status: "approved", category: "MARKETING")
    campaign = user.campaigns.create!(
      name: "Offer",
      template: template,
      status: "completed",
      total_recipients: 10,
      delivered_count: 8,
      failed_count: 2
    )
    sign_in user

    get campaign_path(campaign)

    expect(response.body).to include("Estimated delivery cost")
    expect(response.body).to include("$0.23")
    expect(response.body).to include("More than 20% of this campaign failed")
  end
end
