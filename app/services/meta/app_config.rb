module Meta
  class AppConfig
    class InvalidDisplayName < StandardError; end

    DEFAULT_DISPLAY_NAME = "Marquee".freeze
    LOGIN_PERMISSIONS = %w[whatsapp_business_management whatsapp_business_messaging].map(&:freeze).freeze
    RESERVED_BRAND_PATTERN = /(?<![[:alnum:]])(meta|whatsapp|facebook)(?![[:alnum:]])/i
    NUMERIC_ID_PATTERN = /\A\d+\z/

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

      def app_id
        numeric_setting("META_APP_ID")
      end

      def embedded_signup_configuration_id
        numeric_setting("META_EMBEDDED_SIGNUP_CONFIG_ID")
      end

      def embedded_signup_ready?
        app_id.present? &&
          embedded_signup_configuration_id.present? &&
          ENV["META_APP_SECRET"].to_s.strip.present?
      end

      private

      def numeric_setting(key)
        value = ENV[key].to_s.strip
        value if value.match?(NUMERIC_ID_PATTERN)
      end
    end
  end
end
