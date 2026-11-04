module Meta
  class AppConfig
    class InvalidDisplayName < StandardError; end

    DEFAULT_DISPLAY_NAME = "Marquee".freeze
    LOGIN_PERMISSIONS = %w[whatsapp_business_management whatsapp_business_messaging].freeze
    RESERVED_BRAND_PATTERN = /(?<![[:alnum:]])(meta|whatsapp|facebook)(?![[:alnum:]])/i

    class << self
      def login_permissions
        LOGIN_PERMISSIONS
      end

      def login_scope
        LOGIN_PERMISSIONS.join(",")
      end

      def display_name
        name = ENV["META_APP_DISPLAY_NAME"].to_s.strip
        return DEFAULT_DISPLAY_NAME if name.empty?

        if name.match?(RESERVED_BRAND_PATTERN)
          raise InvalidDisplayName, "The app name cannot use Meta, WhatsApp or Facebook as a word"
        end

        name
      end

      def embedded_signup_ready?
        configured?("META_APP_ID") &&
          configured?("META_EMBEDDED_SIGNUP_CONFIG_ID") &&
          configured?("META_APP_SECRET")
      end

      private

      def configured?(key)
        ENV[key].to_s.strip.present?
      end
    end
  end
end
