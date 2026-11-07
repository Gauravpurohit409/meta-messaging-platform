require "rails_helper"
require "rake"

RSpec.describe Retention do
  around do |example|
    keys = %w[RETENTION_WEBHOOK_DAYS RETENTION_RECIPIENT_DAYS]
    saved = keys.to_h { |key| [ key, ENV[key] ] }
    keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  it "deletes old webhook events and old recipients of finished campaigns" do
    old_event = WebhookEvent.create!(event_type: "messages", payload: {}, created_at: 31.days.ago, updated_at: 31.days.ago)
    fresh_event = WebhookEvent.create!(event_type: "messages", payload: {})
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    finished = user.campaigns.create!(template: template, name: "Old", status: "completed", completed_at: 181.days.ago, default_parameters: { "body_1" => "A", "body_2" => "B" })
    running = user.campaigns.create!(template: template, name: "Now", status: "running", default_parameters: { "body_1" => "A", "body_2" => "B" })
    draft = user.campaigns.create!(template: template, name: "Later", status: "draft", default_parameters: { "body_1" => "A", "body_2" => "B" })
    old_recipient = finished.recipients.create!(phone_number: "919830001111")
    running.recipients.create!(phone_number: "919830002222")
    draft.recipients.create!(phone_number: "919830003333")
    sent_count = finished.sent_count

    result = described_class.purge!

    expect(WebhookEvent.find_by(id: old_event.id)).to be_nil
    expect(WebhookEvent.find_by(id: fresh_event.id)).to be_present
    expect(CampaignRecipient.find_by(id: old_recipient.id)).to be_nil
    expect(running.recipients.count).to eq(1)
    expect(draft.recipients.count).to eq(1)
    expect(finished.reload.sent_count).to eq(sent_count)
    expect(result[:webhook_events]).to eq(1)
    expect(result[:campaign_recipients]).to eq(1)
  end

  it "deletes old inbound replies and recipients of failed campaigns that never recorded a completion time" do
    user = create(:user)
    old_reply = InboundMessage.create!(
      whatsapp_account: user.whatsapp_account,
      wa_message_id: "old",
      from_number: "919830001111",
      body: "STOP",
      received_at: 31.days.ago
    )
    fresh_reply = InboundMessage.create!(
      whatsapp_account: user.whatsapp_account,
      wa_message_id: "fresh",
      from_number: "919830001111",
      body: "Hello",
      received_at: Time.current
    )
    template = create(:template, user: user, status: "approved")
    failed = user.campaigns.create!(template: template, name: "Failed", status: "failed", completed_at: nil, default_parameters: { "body_1" => "A", "body_2" => "B" })
    failed.update_columns(updated_at: 181.days.ago)
    recipient = failed.recipients.create!(phone_number: "919830004444")

    result = described_class.purge!

    expect(InboundMessage.find_by(id: old_reply.id)).to be_nil
    expect(InboundMessage.find_by(id: fresh_reply.id)).to be_present
    expect(CampaignRecipient.find_by(id: recipient.id)).to be_nil
    expect(result[:inbound_messages]).to eq(1)
  end

  it "honors a shorter webhook window and ignores bad values" do
    WebhookEvent.create!(event_type: "messages", payload: {}, created_at: 8.days.ago, updated_at: 8.days.ago)
    ENV["RETENTION_WEBHOOK_DAYS"] = "7"
    expect(described_class.purge![:webhook_events]).to eq(1)

    WebhookEvent.create!(event_type: "messages", payload: {}, created_at: 8.days.ago, updated_at: 8.days.ago)
    ENV["RETENTION_WEBHOOK_DAYS"] = "0"
    expect(described_class.webhook_days).to eq(30)
    ENV["RETENTION_WEBHOOK_DAYS"] = "-3"
    expect(described_class.webhook_days).to eq(30)
    ENV["RETENTION_WEBHOOK_DAYS"] = "nope"
    expect(described_class.webhook_days).to eq(30)
  end

  it "runs the rake task" do
    Rails.application.load_tasks
    expect { Rake::Task["retention:purge"].invoke }.not_to raise_error
  end
end
