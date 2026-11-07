module Inbox
  class ApplyInboundMessages
    STOP_WORDS = [ "stop", "stop all", "unsubscribe", "cancel", "end", "quit", "opt out", "optout" ].freeze
    START_WORDS = %w[start unstop subscribe].freeze

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @value = payload["value"].is_a?(Hash) ? payload["value"] : {}
    end

    def call
      account = WhatsappAccount.find_by(phone_number_id: @value.dig("metadata", "phone_number_id").to_s)
      return if account.nil?

      Array(@value["messages"]).each { |message| apply(account, message) }
    end

    private

    def apply(account, message)
      id = message["id"].to_s
      return if id.blank? || InboundMessage.exists?(wa_message_id: id)

      from = PhoneNumbers.normalize(message["from"])
      text = text_of(message)
      InboundMessage.create!(
        whatsapp_account: account,
        wa_message_id: id,
        from_number: from,
        message_type: message["type"].presence || "text",
        body: text,
        received_at: Time.zone.at(message["timestamp"].to_i)
      )

      word = text.to_s.downcase.gsub(/[[:punct:]]/, "").squeeze(" ").strip
      if STOP_WORDS.include?(word)
        Consent.revoke!(user: account.user, phone_number: from, reason: word)
      elsif START_WORDS.include?(word)
        Consent.restore!(user: account.user, phone_number: from)
      end
    end

    def text_of(message)
      message.dig("text", "body").presence || message.dig("button", "text").presence || message.dig("button", "payload")
    end
  end
end
