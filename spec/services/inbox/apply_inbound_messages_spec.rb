require "rails_helper"

RSpec.describe Inbox::ApplyInboundMessages do
  let(:user) { create(:user) }
  let(:account) { user.whatsapp_account }

  before do
    account.update!(phone_number_id: "222", waba_id: "111", demo_mode: true)
  end

  def payload(body: "Hello", id: "wamid.1", from: "919830001111", phone_number_id: "222", message: nil)
    {
      "waba_id" => "111",
      "value" => {
        "metadata" => { "phone_number_id" => phone_number_id },
        "messages" => [
          message || {
            "id" => id,
            "from" => from,
            "timestamp" => "1762500000",
            "type" => "text",
            "text" => { "body" => body }
          }
        ]
      }
    }
  end

  it "stores the inbound message" do
    described_class.call(payload)

    message = InboundMessage.last
    expect(message.from_number).to eq("919830001111")
    expect(message.body).to eq("Hello")
    expect(message.message_type).to eq("text")
    expect(message.received_at).to eq(Time.zone.at(1_762_500_000))
  end

  [ "STOP", " Stop! ", "opt out", "Unsubscribe" ].each do |word|
    it "revokes consent for #{word.inspect}" do
      described_class.call(payload(body: word, id: "wamid.#{word.object_id}"))

      consent = Consent.find_by(user: user, phone_number: "919830001111")
      expect(consent.revoked_at).to be_present
    end
  end

  it "does not treat a sentence containing stop as an opt-out" do
    described_class.call(payload(body: "please do not stop"))

    expect(Consent.find_by(user: user, phone_number: "919830001111")).to be_nil
  end

  it "restores consent after START" do
    Consent.revoke!(user: user, phone_number: "919830001111", reason: "stop")
    described_class.call(payload(body: "START", id: "wamid.2"))

    expect(Consent.find_by(user: user, phone_number: "919830001111").revoked_at).to be_nil
  end

  it "revokes when a quick reply says Stop" do
    described_class.call(payload(message: {
      "id" => "wamid.btn",
      "from" => "919830001111",
      "timestamp" => "1762500000",
      "type" => "button",
      "button" => { "text" => "Stop", "payload" => "STOP" }
    }))

    expect(Consent.find_by(user: user, phone_number: "919830001111").revoked_at).to be_present
  end

  it "stores one row when the same message arrives twice" do
    described_class.call(payload(body: "STOP"))
    described_class.call(payload(body: "STOP"))

    expect(InboundMessage.count).to eq(1)
    expect(Consent.where(user: user, phone_number: "919830001111").count).to eq(1)
  end

  it "ignores an unknown phone number id" do
    expect { described_class.call(payload(phone_number_id: "missing")) }.not_to raise_error
    expect(InboundMessage.count).to eq(0)
  end

  it "ignores a status-only payload" do
    described_class.call("waba_id" => "111", "value" => { "statuses" => [ { "id" => "wamid.x", "status" => "delivered" } ] })

    expect(InboundMessage.count).to eq(0)
  end

  it "does not revoke another desk" do
    other = create(:user)
    Consent.record!(user: other, phone_number: "919830001111", source: "manual_entry", wording: "Theirs")

    described_class.call(payload(body: "STOP"))

    expect(Consent.find_by(user: other).revoked_at).to be_nil
    expect(Consent.find_by(user: user).revoked_at).to be_present
  end
end
