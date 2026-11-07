require "rails_helper"

RSpec.describe "Inbox", type: :request do
  include Devise::Test::IntegrationHelpers

  it "sends a signed-out visitor to sign in" do
    get inbox_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows only the signed-in desk, newest first, and at most 100" do
    user = create(:user)
    other = create(:user)
    InboundMessage.create!(whatsapp_account: other.whatsapp_account, wa_message_id: "other", from_number: "919800000000", body: "Secret reply", received_at: Time.current)
    101.times do |index|
      InboundMessage.create!(
        whatsapp_account: user.whatsapp_account,
        wa_message_id: "mine-#{index}",
        from_number: "919830001111",
        body: "Reply #{index}",
        received_at: Time.current - (101 - index).minutes
      )
    end
    sign_in user

    get inbox_path

    expect(response.body).to include("Reply 100")
    expect(response.body).not_to include("Reply 0")
    expect(response.body).not_to include("Secret reply")
    expect(response.body).to include('href="/inbox"')
  end

  it "shows an empty state" do
    sign_in create(:user)

    get inbox_path

    expect(response.body).to include("No replies yet.")
  end
end