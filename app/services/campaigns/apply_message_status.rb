module Campaigns
  class ApplyMessageStatus
    def self.call(payload)
      value = payload["value"] || {}
      Array(value["statuses"]).each do |status|
        recipient = CampaignRecipient.find_by(message_id: status["id"])
        next if recipient.nil?

        case status["status"]
        when "sent"
          recipient.mark_sent!(status["id"])
        when "delivered"
          recipient.mark_delivered!
        when "read"
          recipient.mark_read!
        when "failed"
          error = Array(status["errors"]).first || {}
          recipient.mark_failed!(
            code: error["code"],
            message: error["title"].presence || error["message"].presence || "Delivery failed"
          )
        end
      end
    end
  end
end
