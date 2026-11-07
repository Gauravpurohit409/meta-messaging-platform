require "rails_helper"

RSpec.describe "Registration confirmation", type: :request do
  it "sends a confirmation email and does not sign the new desk in" do
    expect {
      post user_registration_path, params: {
        user: { name: "Asha Menon", company: "Northwind", email: "asha@marquee.test", password: "password123", password_confirmation: "password123" }
      }
    }.to change { ActionMailer::Base.deliveries.size }.by(1)

    user = User.find_by(email: "asha@marquee.test")
    expect(user.confirmed_at).to be_nil
    expect(ActionMailer::Base.deliveries.last.to).to eq([ "asha@marquee.test" ])

    get dashboard_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "confirms the account from the email link" do
    post user_registration_path, params: {
      user: { name: "Asha Menon", email: "asha@marquee.test", password: "password123", password_confirmation: "password123" }
    }
    token = ActionMailer::Base.deliveries.last.body.encoded[/confirmation_token=([^"&\s]+)/, 1]

    get user_confirmation_path(confirmation_token: token)

    expect(User.find_by(email: "asha@marquee.test").confirmed_at).to be_present
    post user_session_path, params: { user: { email: "asha@marquee.test", password: "password123" } }
    expect(response).to redirect_to(dashboard_path)
  end

  it "refuses an unconfirmed sign-in" do
    create(:user, :unconfirmed, email: "pending@marquee.test")

    post user_session_path, params: { user: { email: "pending@marquee.test", password: "password123" } }
    follow_redirect!

    expect(response.body).to match(/confirm your email/i)
  end

  it "locks the account after five failed sign-ins" do
    user = create(:user)

    5.times { post user_session_path, params: { user: { email: user.email, password: "wrong-password" } } }
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    expect(response).not_to redirect_to(dashboard_path)
    expect(user.reload.access_locked?).to be(true)
    expect(ActionMailer::Base.deliveries.map(&:subject).join).to match(/unlock/i)
  end

  it "unlocks the account from the email link" do
    user = create(:user)
    5.times { post user_session_path, params: { user: { email: user.email, password: "wrong-password" } } }
    token = ActionMailer::Base.deliveries.last.body.encoded[/unlock_token=([^"&\s]+)/, 1]

    get user_unlock_path(unlock_token: token)

    expect(user.reload.access_locked?).to be(false)
  end

  it "signs in an already confirmed desk" do
    user = create(:user)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    expect(response).to redirect_to(dashboard_path)
  end
end