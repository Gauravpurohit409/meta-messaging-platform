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
end
