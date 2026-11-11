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

  def running_campaign(user, category:)
    template = create(:template, user: user, status: "approved", category: category)
    campaign = user.campaigns.create!(
      template: template,
      name: "Pickup",
      status: "running",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    campaign.recipients.create!(phone_number: "919830001111", status: "queued")
  end

  it "does not send a marketing message to someone who opted out" do
    user = create(:user)
    recipient = running_campaign(user, category: "MARKETING")
    Consent.revoke!(user: user, phone_number: recipient.phone_number, reason: "stop")
    expect(Meta::Client).not_to receive(:new)

    described_class.perform_now(recipient.id)

    expect(recipient.reload.status).to eq("failed")
    expect(recipient.error_code).to eq("opted_out")
    expect(recipient.error_message).to match(/opted out/i)
  end

  it "still sends a utility message to someone who opted out" do
    user = create(:user)
    recipient = running_campaign(user, category: "UTILITY")
    Consent.revoke!(user: user, phone_number: recipient.phone_number, reason: "stop")

    described_class.perform_now(recipient.id)

    expect(recipient.reload.status).to eq("sent")
  end

  it "skips a marketing send after the person replies STOP" do
    user = create(:user)
    user.whatsapp_account.update!(phone_number_id: "222")
    recipient = running_campaign(user, category: "MARKETING")
    Inbox::ApplyInboundMessages.call(
      "value" => {
        "metadata" => { "phone_number_id" => "222" },
        "messages" => [
          { "id" => "wamid.stop", "from" => recipient.phone_number, "timestamp" => "1762500000", "type" => "text", "text" => { "body" => "STOP" } }
        ]
      }
    )

    described_class.perform_now(recipient.id)

    expect(recipient.reload.error_code).to eq("opted_out")
  end

  it "sends version B with the version B template" do
    user = create(:user)
    version_a = create(:template, user: user, status: "approved", category: "UTILITY", name: "version_a")
    version_b = create(:template, user: user, status: "approved", category: "UTILITY", name: "version_b")
    campaign = user.campaigns.create!(
      template: version_a,
      variant_template: version_b,
      name: "Compare",
      status: "running",
      default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" }
    )
    recipient = campaign.recipients.create!(phone_number: "919830001111", status: "queued", variant: "b")
    client = instance_double(Meta::Client)
    allow(Meta::Client).to receive(:new).and_return(client)
    expect(client).to receive(:send_template_message).with(hash_including(template: version_b)).and_return("messages" => [ { "id" => "wamid.b" } ])

    described_class.perform_now(recipient.id)

    expect(recipient.reload.message_id).to eq("wamid.b")
  end

  it "sends a marketing message when consent is active" do
    user = create(:user)
    recipient = running_campaign(user, category: "MARKETING")
    Consent.record!(user: user, phone_number: recipient.phone_number, source: "campaign_upload", wording: "Checkout")

    described_class.perform_now(recipient.id)

    expect(recipient.reload.status).to eq("sent")
  end
end
