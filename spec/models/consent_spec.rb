require "rails_helper"

RSpec.describe Consent, type: :model do
  let(:user) { create(:user) }

  it "stores a normalized number with the source, wording, and time" do
    record = described_class.record!(
      user: user,
      phone_number: "+91 98300 01111",
      source: "campaign_upload",
      wording: "Checkout form"
    )

    expect(record.phone_number).to eq("919830001111")
    expect(record.source).to eq("campaign_upload")
    expect(record.wording).to eq("Checkout form")
    expect(record.consented_at).to be_present
    expect(record).to be_active
  end

  it "returns the same row when the number is recorded twice" do
    first = described_class.record!(user: user, phone_number: "919830001111", source: "manual_entry", wording: "Desk")
    second = described_class.record!(user: user, phone_number: "+91 98300 01111", source: "manual_entry", wording: "Again")

    expect(second.id).to eq(first.id)
    expect(described_class.where(user: user).count).to eq(1)
  end

  it "does not re-activate a revoked number" do
    described_class.revoke!(user: user, phone_number: "919830001111", reason: "stop")
    record = described_class.record!(user: user, phone_number: "919830001111", source: "campaign_upload", wording: "Checkout")

    expect(record.revoked_at).to be_present
  end

  it "creates a revoked row when the number has no record" do
    record = described_class.revoke!(user: user, phone_number: "919830001111", reason: "stop")

    expect(record.revoked_at).to be_present
    expect(record.revoked_reason).to eq("stop")
  end

  it "keeps the first revoked time" do
    first = described_class.revoke!(user: user, phone_number: "919830001111", reason: "stop")
    second = described_class.revoke!(user: user, phone_number: "919830001111", reason: "quit")

    expect(second.revoked_at).to eq(first.revoked_at)
    expect(second.revoked_reason).to eq("stop")
  end

  it "clears a revocation and returns nil when there is no row" do
    described_class.revoke!(user: user, phone_number: "919830001111", reason: "stop")
    restored = described_class.restore!(user: user, phone_number: "919830001111")

    expect(restored.revoked_at).to be_nil
    expect(restored.revoked_reason).to be_nil
    expect(described_class.restore!(user: user, phone_number: "919800000000")).to be_nil
  end

  it "lets two desks hold the same number" do
    other = create(:user)
    described_class.record!(user: user, phone_number: "919830001111", source: "manual_entry", wording: "A")
    described_class.record!(user: other, phone_number: "919830001111", source: "manual_entry", wording: "B")

    expect(described_class.where(phone_number: "919830001111").count).to eq(2)
  end

  it "rejects an unknown source" do
    record = described_class.new(user: user, phone_number: "919830001111", source: "poster", wording: "A", consented_at: Time.current)

    expect(record).not_to be_valid
  end
end
