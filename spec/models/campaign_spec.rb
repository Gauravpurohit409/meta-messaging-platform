require "rails_helper"

RSpec.describe Campaign, type: :model do
  it "counts everyone who has left the queue, including a later delivery failure" do
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(
      name: "Evening restock",
      template: template,
      status: "running",
      total_recipients: 2
    )
    campaign.recipients.create!(phone_number: "919811110101", status: "sent")
    failed = campaign.recipients.create!(phone_number: "919833330000", status: "sent")

    expect(campaign.dispatched_count).to eq(2)

    failed.update!(status: "failed", error_code: "131026", error_message: "undeliverable")
    expect(campaign.dispatched_count).to eq(2)
  end

  it "estimates delivery cost from the template category and delivered messages only" do
    user = create(:user)
    marketing = create(:template, user: user, status: "approved", category: "MARKETING")
    utility = create(:template, user: user, status: "approved", category: "UTILITY")
    authentication = create(:template, user: user, status: "approved", category: "AUTHENTICATION")

    marketing_campaign = user.campaigns.create!(name: "Offer", template: marketing, delivered_count: 100, sent_count: 120)
    utility_campaign = user.campaigns.create!(name: "Order", template: utility, delivered_count: 10)
    authentication_campaign = user.campaigns.create!(name: "Code", template: authentication, delivered_count: 10)
    none = user.campaigns.create!(name: "Empty", template: utility, delivered_count: 0, sent_count: 4)

    expect(marketing_campaign.estimated_delivery_cost).to eq(BigDecimal("2.875"))
    expect(utility_campaign.estimated_delivery_cost).to eq(BigDecimal("0.0391"))
    expect(authentication_campaign.estimated_delivery_cost).to eq(BigDecimal("0.0391"))
    expect(none.estimated_delivery_cost).to eq(0)
  end

  it "flags a high failure rate once at least five recipients have been counted" do
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    calm = user.campaigns.create!(name: "Calm", template: template, total_recipients: 10, failed_count: 1)
    hot = user.campaigns.create!(name: "Hot", template: template, total_recipients: 10, failed_count: 2)
    small = user.campaigns.create!(name: "Small", template: template, total_recipients: 4, failed_count: 4)

    expect(calm.high_failure_rate?).to be(false)
    expect(hot.high_failure_rate?).to be(true)
    expect(small.high_failure_rate?).to be(false)
  end

  it "rejects a version B template of a different type" do
    user = create(:user)
    campaign = user.campaigns.new(
      name: "Compare",
      template: create(:template, user: user, status: "approved", category: "UTILITY"),
      variant_template: create(:template, user: user, status: "approved", category: "MARKETING", footer_text: "Reply STOP to opt out")
    )

    expect(campaign).not_to be_valid
    expect(campaign.errors[:variant_template].join).to include("same type")
  end
end
