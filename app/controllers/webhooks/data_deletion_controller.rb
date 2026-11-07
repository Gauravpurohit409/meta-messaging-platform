module Webhooks
  class DataDeletionController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token

    def create
      payload = parse_signed_request(params[:signed_request])
      if payload.nil?
        head :bad_request
        return
      end

      record = DataDeletionRequest.create!(meta_user_id: payload["user_id"])
      render json: {
        url: data_deletion_status_url(code: record.confirmation_code),
        confirmation_code: record.confirmation_code
      }
    end

    private

    def parse_signed_request(raw)
      encoded_signature, encoded_payload = raw.to_s.split(".", 2)
      secret = ENV["META_APP_SECRET"].to_s
      return nil if encoded_signature.blank? || encoded_payload.blank? || secret.blank?

      signature = Base64.urlsafe_decode64(encoded_signature)
      expected = OpenSSL::HMAC.digest("SHA256", secret, encoded_payload)
      return nil unless signature.bytesize == expected.bytesize &&
                        ActiveSupport::SecurityUtils.secure_compare(signature, expected)

      JSON.parse(Base64.urlsafe_decode64(encoded_payload))
    rescue ArgumentError, JSON::ParserError
      nil
    end
  end
end
