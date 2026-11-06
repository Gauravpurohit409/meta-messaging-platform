module Accounts
  class ApplyAccountUpdate
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload
    end

    def call
      account = WhatsappAccount.find_by(waba_id: waba_id)
      return if account.nil?

      case event
      when "PARTNER_APP_UNINSTALLED", "ACCOUNT_DELETED"
        account.release_meta_connection!
      when "DISABLED_UPDATE"
        apply_ban(account)
      when "ACCOUNT_RESTRICTION", "ACCOUNT_OFFBOARDED"
        account.update!(restricted: true)
      when "ACCOUNT_RECONNECTED"
        account.update!(restricted: false)
      when "ACCOUNT_VIOLATION"
        account.update!(restricted: false, policy_notice: "ACCOUNT_VIOLATION")
      end
    end

    private

    def waba_id
      value.dig("waba_info", "waba_id").presence ||
        value["waba_id"].presence ||
        @payload["waba_id"].presence
    end

    def value
      @value ||= @payload["value"].is_a?(Hash) ? @payload["value"] : {}
    end

    def event
      value["event"].to_s
    end

    def apply_ban(account)
      case value.dig("ban_info", "waba_ban_state").to_s
      when "DISABLE"
        account.update!(restricted: true)
      when "REINSTATE"
        account.update!(restricted: false)
      when "SCHEDULE_FOR_DISABLE"
        account.update!(restricted: false, policy_notice: "SCHEDULE_FOR_DISABLE")
      end
    end
  end
end
