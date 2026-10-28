require "rails_helper"

RSpec.describe "Meta webhook", type: :request do
  it "confirms a verify token that belongs to a desk" do
    account = create(:user).whatsapp_account
    get "/webhooks/meta", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => account.verify_token,
      "hub.challenge" => "12345"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("12345")
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
end
