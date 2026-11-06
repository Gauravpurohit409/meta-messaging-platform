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

  it "marks the desk as needing a reconnect when Meta rejects the token" do
    user = create(:user)
    account = user.whatsapp_account
    account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "tok")
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(
      template: template,
      name: "Pickup",
      status: "running",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    recipient = campaign.recipients.create!(phone_number: "919830001111", status: "queued")
    allow_any_instance_of(Meta::Client).to receive(:send_template_message).and_raise(
      Meta::Client::Error.new("Error validating access token", code: 190)
    )

    described_class.perform_now(recipient.id)

    expect(recipient.reload.status).to eq("failed")
    expect(recipient.message_id).to be_nil
    expect(account.reload.reconnect_required).to be(true)
  end
end
