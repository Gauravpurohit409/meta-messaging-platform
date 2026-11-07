require "rails_helper"

RSpec.describe ProcessWebhookJob do
  it "revokes consent from an inbound STOP and marks the event processed" do
    user = create(:user)
    user.whatsapp_account.update!(phone_number_id: "222")
    event = WebhookEvent.create!(
      event_type: "messages",
      payload: {
        "waba_id" => "111",
        "value" => {
          "metadata" => { "phone_number_id" => "222" },
          "messages" => [
            { "id" => "wamid.stop", "from" => "919830001111", "timestamp" => "1762500000", "type" => "text", "text" => { "body" => "STOP" } }
          ]
        }
      }
    )

    described_class.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(Consent.find_by(user: user, phone_number: "919830001111").revoked_at).to be_present
  end

  it "still applies delivery statuses" do
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(template: template, name: "Pickup", status: "running", default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" })
    recipient = campaign.recipients.create!(phone_number: "919830001111", status: "sent", message_id: "wamid.sent")
    event = WebhookEvent.create!(
      event_type: "messages",
      payload: { "value" => { "statuses" => [ { "id" => "wamid.sent", "status" => "delivered" } ] } }
    )

    described_class.perform_now(event.id)

    expect(recipient.reload.status).to eq("delivered")
    expect(event.reload).to be_processed
  end
end
