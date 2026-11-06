require "rails_helper"

RSpec.describe "Meta webhook", type: :request do
  it "confirms the app-level verify token and echoes the challenge" do
    account = create(:user).whatsapp_account

    with_verify_token("app-verify-token") do
      get "/webhooks/meta", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => "app-verify-token",
        "hub.challenge" => "12345"
      }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("12345")
    expect(account.verify_token).not_to eq("app-verify-token")
  end

  it "rejects a desk's own verify token" do
    account = create(:user).whatsapp_account

    with_verify_token("app-verify-token") do
      get "/webhooks/meta", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => account.verify_token,
        "hub.challenge" => "12345"
      }
    end

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a blank token, the wrong token, and a mode other than subscribe" do
    with_verify_token("app-verify-token") do
      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => "", "hub.challenge" => "1" }
      expect(response).to have_http_status(:forbidden)

      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => "nope", "hub.challenge" => "1" }
      expect(response).to have_http_status(:forbidden)

      get "/webhooks/meta", params: { "hub.mode" => "unsubscribe", "hub.verify_token" => "app-verify-token", "hub.challenge" => "1" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "stores a template status event" do
    template = create(:template, status: "pending", meta_template_id: "555")
    payload = {
      entry: [
        {
          id: "waba",
          changes: [
            {
              field: "message_template_status_update",
              value: {
                event: "APPROVED",
                message_template_id: "555",
                message_template_name: template.name,
                message_template_language: "en_US"
              }
            }
          ]
        }
      ]
    }

    expect {
      post "/webhooks/meta", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    }.to have_enqueued_job(ProcessWebhookJob)

    expect(response).to have_http_status(:ok)
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)
    expect(template.reload.status).to eq("approved")
  end

  it "disconnects only the desk Meta removed" do
    removed = live_account(waba_id: "111", phone_number_id: "222", access_token: "removed-token")
    kept = live_account(waba_id: "999", phone_number_id: "333", access_token: "kept-token")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "PARTNER_APP_UNINSTALLED" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(removed.reload.demo_mode).to be(true)
    expect(removed.access_token).to be_nil
    expect(removed.waba_id).to be_nil
    expect(kept.reload.demo_mode).to be(false)
    expect(kept.access_token).to eq("kept-token")
  end

  it "disconnects the desk when the WABA is deleted" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "ACCOUNT_DELETED" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.demo_mode).to be(true)
    expect(account.access_token).to be_nil
    expect(account.phone_number_id).to be_nil
    expect(account.pin_phone_number_id).to eq("222")
  end

  it "does not disconnect a desk when a solution partner is removed" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "PARTNER_REMOVED" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.demo_mode).to be(false)
    expect(account.access_token).to eq("tok")
    expect(account.restricted).to be(false)
  end

  it "stops sends when Meta disables the WABA and keeps the token" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: {
      event: "DISABLED_UPDATE",
      ban_info: { waba_ban_state: "DISABLE" }
    })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(true)
    expect(account.live?).to be(false)
    expect(account.access_token).to eq("tok")
    expect(account.demo_mode).to be(false)
  end

  it "stops sends on a messaging restriction and keeps the token" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: {
      event: "ACCOUNT_RESTRICTION",
      restriction_info: [ { restriction_type: "RESTRICTED_BIZ_INITIATED_MESSAGING" } ]
    })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(true)
    expect(account.live?).to be(false)
    expect(account.access_token).to eq("tok")
  end

  it "stops sends when the number is offboarded and keeps the connection" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "ACCOUNT_OFFBOARDED" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(true)
    expect(account.live?).to be(false)
    expect(account.access_token).to eq("tok")
    expect(account.waba_id).to eq("111")
  end

  it "lets the desk send again when Meta reinstates it" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok", restricted: true)

    post_webhook(waba_id: "111", field: "account_update", value: {
      event: "DISABLED_UPDATE",
      ban_info: { waba_ban_state: "REINSTATE" }
    })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(false)
    expect(account.live?).to be(true)
    expect(account.access_token).to eq("tok")
  end

  it "lets the desk send again when the number is reconnected" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok", restricted: true)

    post_webhook(waba_id: "111", field: "account_update", value: { event: "ACCOUNT_RECONNECTED" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(false)
    expect(account.live?).to be(true)
  end

  it "records a policy warning without stopping sends" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "ACCOUNT_VIOLATION" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(false)
    expect(account.live?).to be(true)
    expect(account.access_token).to eq("tok")
    expect(account.policy_notice).to include("ACCOUNT_VIOLATION")
  end

  it "records a scheduled disable without stopping sends" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: {
      event: "DISABLED_UPDATE",
      ban_info: { waba_ban_state: "SCHEDULE_FOR_DISABLE" }
    })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.restricted).to be(false)
    expect(account.live?).to be(true)
    expect(account.policy_notice).to include("SCHEDULE_FOR_DISABLE")
  end

  it "matches a partner event that names the WABA under waba_info" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(
      waba_id: "other-entry",
      field: "account_update",
      value: { event: "PARTNER_APP_UNINSTALLED", waba_info: { waba_id: "111" } }
    )
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.access_token).to be_nil
  end

  it "leaves desks alone for account updates it does not act on" do
    account = live_account(waba_id: "111", phone_number_id: "222", access_token: "tok")

    post_webhook(waba_id: "111", field: "account_update", value: { event: "VERIFIED_ACCOUNT" })
    ProcessWebhookJob.perform_now(WebhookEvent.last.id)

    expect(account.reload.demo_mode).to be(false)
    expect(account.access_token).to eq("tok")
    expect(account.restricted).to be(false)
    expect(account.policy_notice).to be_blank
  end

  it "ignores an account_update for a WABA Marquee does not know" do
    expect {
      post_webhook(waba_id: "missing", field: "account_update", value: { event: "ACCOUNT_DELETED" })
      ProcessWebhookJob.perform_now(WebhookEvent.last.id)
    }.not_to raise_error
  end

  def live_account(attrs)
    create(:user).whatsapp_account.tap { |account| account.update!(attrs.merge(demo_mode: false)) }
  end

  def post_webhook(waba_id:, field:, value:)
    payload = { entry: [ { id: waba_id, changes: [ { field: field, value: value } ] } ] }
    post "/webhooks/meta", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
  end

  def with_verify_token(token)
    saved = ENV["META_VERIFY_TOKEN"]
    ENV["META_VERIFY_TOKEN"] = token
    yield
  ensure
    saved.nil? ? ENV.delete("META_VERIFY_TOKEN") : ENV["META_VERIFY_TOKEN"] = saved
  end
end
