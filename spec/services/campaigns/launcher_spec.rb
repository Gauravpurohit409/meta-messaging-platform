require "rails_helper"

RSpec.describe Campaigns::Launcher do
  it "refuses a template that is not approved" do
    user = create(:user)
    template = create(:template, user: user, status: "pending")
    campaign = user.campaigns.create!(template: template, name: "Pickup", default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" })
    campaign.recipients.create!(phone_number: "919830001111")

    expect(described_class.call(campaign)).to be(false)
    expect(campaign.errors.full_messages.join).to include("approved")
    expect(CampaignSenderJob).not_to have_been_enqueued
  end

  it "starts a send for an approved template" do
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(
      template: template,
      name: "Pickup",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    campaign.recipients.create!(phone_number: "919830001111")

    expect {
      expect(described_class.call(campaign)).to be(true)
    }.to have_enqueued_job(CampaignSenderJob)

    expect(campaign.reload.status).to eq("running")
  end

  def approved_campaign(category:)
    user = create(:user)
    template = create(:template, user: user, status: "approved", category: category)
    campaign = user.campaigns.create!(
      template: template,
      name: "Pickup",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    campaign.recipients.create!(phone_number: "919830001111")
    campaign
  end

  it "refuses a marketing campaign when a recipient has no opt-in record" do
    campaign = approved_campaign(category: "MARKETING")

    expect(described_class.call(campaign)).to be(false)
    expect(campaign.errors.full_messages.join).to match(/no opt-in record/)
    expect(campaign.reload).to be_draft
  end

  it "launches a marketing campaign when every recipient has a consent row" do
    campaign = approved_campaign(category: "MARKETING")
    Consent.revoke!(user: campaign.user, phone_number: "919830001111", reason: "stop")

    expect(described_class.call(campaign)).to be(true)
    expect(campaign.reload.status).to eq("running")
  end

  it "launches a utility campaign with no consent rows" do
    campaign = approved_campaign(category: "UTILITY")

    expect(described_class.call(campaign)).to be(true)
  end
end
