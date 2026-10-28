module Webhooks
  class MetaController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token

    def verify
      mode = params["hub.mode"]
      token = params["hub.verify_token"].to_s
      challenge = params["hub.challenge"]
      verified = mode == "subscribe" && token.present? && (
        (ENV["META_VERIFY_TOKEN"].present? && token == ENV["META_VERIFY_TOKEN"]) ||
        WhatsappAccount.exists?(verify_token: token)
      )

      if verified
        render plain: challenge
      else
        head :forbidden
      end
    end

    def receive
      payload = request.raw_post
      unless signature_ok?(payload)
        head :unauthorized
        return
      end

      json = JSON.parse(payload)
      Array(json["entry"]).each do |entry|
        Array(entry["changes"]).each do |change|
          event = WebhookEvent.create!(
            event_type: change["field"].presence || "unknown",
            payload: { "waba_id" => entry["id"], "value" => change["value"] }
          )
          ProcessWebhookJob.perform_later(event.id)
        end
      end
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def signature_ok?(payload)
      secret = ENV["META_APP_SECRET"].to_s
      return !Rails.env.production? if secret.blank?

      header = request.headers["X-Hub-Signature-256"].to_s
      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}"
      return false unless header.bytesize == expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(header, expected)
    end
  end
end
