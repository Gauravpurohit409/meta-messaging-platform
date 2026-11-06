require "rails_helper"

RSpec.describe WhatsappAccount do
  def live(waba_id, phone_number_id)
    create(:user).whatsapp_account.tap do |account|
      account.update!(demo_mode: false, waba_id: waba_id, phone_number_id: phone_number_id, access_token: "tok")
    end
  end

  it "rejects a second desk using the same WABA" do
    live("111", "222")
    second = create(:user).whatsapp_account

    saved = second.update(demo_mode: false, waba_id: "111", phone_number_id: "444", access_token: "other")

    expect(saved).to be(false)
    expect(second.errors[:waba_id].join).to match(/taken|connected/i)
  end

  it "rejects a second desk using the same phone number" do
    live("111", "222")
    second = create(:user).whatsapp_account

    saved = second.update(demo_mode: false, waba_id: "999", phone_number_id: "222", access_token: "other")

    expect(saved).to be(false)
    expect(second.errors[:phone_number_id].join).to match(/taken|connected/i)
  end

  it "allows several demo desks with no WABA" do
    create(:user)
    create(:user)

    expect(WhatsappAccount.where(waba_id: nil).count).to be >= 2
  end

  it "has a unique index for each id so a race cannot save both" do
    indexes = described_class.connection.indexes(:whatsapp_accounts)

    expect(indexes).to include(an_object_having_attributes(columns: [ "waba_id" ], unique: true))
    expect(indexes).to include(an_object_having_attributes(columns: [ "phone_number_id" ], unique: true))
  end
end
