require "rails_helper"

RSpec.describe SendMessageJob do
  it "does not send or invent a delivery when Meta has restricted the desk" do
    user = create(:user)
    user.whatsapp_account.update!(
      demo_mode: false,
      waba_id: "111",
      phone_number_id: "222",
      access_token: "tok",
      restricted: true
    )
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(
      template: template,
      name: "Pickup",
      status: "running",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    recipient = campaign.recipients.create!(phone_number: "919830001111", status: "queued")

    described_class.perform_now(recipient.id)

    expect(recipient.reload.status).to eq("failed")
    expect(recipient.message_id).to be_nil
    expect(recipient.error_message).to match(/restricted/i)
  end
end
