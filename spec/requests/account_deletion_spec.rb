require "rails_helper"

RSpec.describe "Account deletion", type: :request do
  include Devise::Test::IntegrationHelpers

  it "removes the desk and its data" do
    user = create(:user)
    template = create(:template, user: user, status: "approved")
    campaign = user.campaigns.create!(template: template, name: "Pickup", default_parameters: { "body_1" => "Asha", "body_2" => "NW-1" })
    campaign.recipients.create!(phone_number: "919830001111")
    Consent.record!(user: user, phone_number: "919830001111", source: "manual_entry", wording: "Desk")
    other = create(:user)
    sign_in user

    delete user_registration_path

    expect(response).to redirect_to(root_path)
    expect(User.find_by(id: user.id)).to be_nil
    expect(Template.where(user_id: user.id)).to be_empty
    expect(Campaign.where(user_id: user.id)).to be_empty
    expect(Consent.where(user_id: user.id)).to be_empty
    expect(WhatsappAccount.where(user_id: user.id)).to be_empty
    expect(User.find_by(id: other.id)).to be_present
  end

  it "disconnects a live desk and still deletes the account if Meta is unreachable" do
    user = create(:user)
    user.whatsapp_account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "tok")
    expect(Meta::EmbeddedSignup).to receive(:disconnect).once.and_raise(StandardError, "down")
    sign_in user
    delete user_registration_path

    expect(User.find_by(id: user.id)).to be_nil
  end

  it "does not call Meta for a demo desk" do
    user = create(:user)
    expect(Meta::EmbeddedSignup).not_to receive(:disconnect)
    sign_in user

    delete user_registration_path

    expect(User.find_by(id: user.id)).to be_nil
  end

  it "offers account deletion on the account page" do
    sign_in create(:user)

    get edit_user_registration_path

    expect(response.body).to include("Delete my account")
  end
end