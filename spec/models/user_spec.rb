require "rails_helper"

RSpec.describe User, type: :model do
  it "requires a name and opens a demo WhatsApp connection" do
    user = build(:user, name: "")
    expect(user).not_to be_valid

    user.name = "Asha Menon"
    user.save!
    expect(user.whatsapp_account).to be_demo_mode
    expect(user.whatsapp_account.verify_token).to be_present
  end

  it "confirms email and locks after repeated failures" do
    expect(User.devise_modules).to include(:confirmable, :lockable)
  end

  it "removes consents when the desk is deleted" do
    user = create(:user)
    Consent.record!(user: user, phone_number: "919830001111", source: "manual_entry", wording: "Desk")

    user.destroy!

    expect(Consent.where(user_id: user.id)).to be_empty
  end
end
