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
end
