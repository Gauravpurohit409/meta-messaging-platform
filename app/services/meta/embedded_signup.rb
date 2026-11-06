module Meta
  class EmbeddedSignup
    CODE_PATTERN = /\A[A-Za-z0-9_-]{1,2000}\z/
    ID_PATTERN = /\A\d{1,32}\z/

    def self.connect(account:, code:, waba_id:, phone_number_id:)
      new(account).connect(code:, waba_id:, phone_number_id:)
    end

    def self.disconnect(positional = nil, account: nil)
      new(account || positional).disconnect
    end

    def self.acceptable?(code:, waba_id:, phone_number_id:)
      code.to_s.strip.match?(CODE_PATTERN) &&
        waba_id.to_s.strip.match?(ID_PATTERN) &&
        phone_number_id.to_s.strip.match?(ID_PATTERN)
    end

    def initialize(account)
      @account = account
    end

    def connect(code:, waba_id:, phone_number_id:)
      code = code.to_s.strip
      waba_id = waba_id.to_s.strip
      phone_number_id = phone_number_id.to_s.strip
      return false unless inputs_ok?(code, waba_id, phone_number_id)
      return false unless configured?
      return false unless available?(waba_id, phone_number_id)

      token = exchange(code)
      return false if token.blank?
      return false unless subscribe(waba_id, token)

      pin = pin_for(phone_number_id)
      return false unless register(phone_number_id, token, pin)

      details = fetch_details(waba_id, phone_number_id, token)
      @account.update!(
        demo_mode: false,
        access_token: token,
        waba_id: waba_id,
        phone_number_id: phone_number_id,
        registration_pin: pin,
        pin_phone_number_id: phone_number_id,
        business_name: details[:business_name],
        display_phone: details[:display_phone].presence || @account.display_phone,
        quality_rating: details[:quality_rating],
        messaging_limit: details[:messaging_limit],
        connected_at: Time.current,
        restricted: false,
        reconnect_required: false
      )
      true
    rescue Faraday::Error => error
      @account.errors.add(:base, "Could not reach Meta (#{error.message})")
      false
    end

    def disconnect
      return true if @account.demo_mode? || @account.waba_id.blank? || @account.access_token.blank?

      refusal = unsubscribe
      @account.release_meta_connection!
      return true if refusal.nil?

      @account.errors.add(:base, refusal)
      false
    rescue Faraday::Error => error
      @account.release_meta_connection!
      @account.errors.add(:base, "Could not reach Meta (#{error.message})")
      false
    end

    private

    def inputs_ok?(code, waba_id, phone_number_id)
      return true if self.class.acceptable?(code: code, waba_id: waba_id, phone_number_id: phone_number_id)

      @account.errors.add(:base, "Check the signup code and account ids, then try again.")
      false
    end

    def configured?
      return true if Meta::AppConfig.embedded_signup_ready?

      @account.errors.add(:base, "Embedded Signup is not configured")
      false
    end

    def available?(waba_id, phone_number_id)
      taken = WhatsappAccount.where.not(id: @account.id)
      if taken.exists?(waba_id: waba_id) || taken.exists?(phone_number_id: phone_number_id)
        @account.errors.add(:base, "That WhatsApp account is already connected to another desk")
        return false
      end
      true
    end

    def exchange(code)
      data = call(:get, "oauth/access_token", params: {
        client_id: Meta::AppConfig.app_id,
        client_secret: ENV["META_APP_SECRET"].to_s,
        code: code
      })
      token = data["access_token"].to_s
      return token if token.present?

      @account.errors.add(:base, "Meta did not return a token")
      nil
    rescue Meta::Client::Error => error
      @account.errors.add(:base, failure_message(error))
      nil
    end

    def subscribe(waba_id, token)
      call(:post, "#{waba_id}/subscribed_apps", token: token, body: {})
      true
    rescue Meta::Client::Error => error
      @account.errors.add(:base, failure_message(error))
      false
    end

    def register(phone_number_id, token, pin)
      call(:post, "#{phone_number_id}/register", token: token, body: { messaging_product: "whatsapp", pin: pin })
      true
    rescue Meta::Client::Error => error
      @account.errors.add(:base, failure_message(error))
      false
    end

    def fetch_details(waba_id, phone_number_id, token)
      waba = call(:get, waba_id, token: token, params: { fields: "name" })
      phone = call(:get, phone_number_id, token: token, params: {
        fields: "display_phone_number,verified_name,quality_rating,messaging_limit_tier"
      })
      {
        business_name: waba["name"],
        display_phone: phone["display_phone_number"],
        quality_rating: phone["quality_rating"],
        messaging_limit: phone["messaging_limit_tier"]
      }
    rescue Meta::Client::Error, Faraday::Error
      {}
    end

    def unsubscribe
      call(:delete, "#{@account.waba_id}/subscribed_apps", token: @account.access_token)
      nil
    rescue Meta::Client::Error => error
      error.message
    end

    def pin_for(phone_number_id)
      if @account.pin_phone_number_id == phone_number_id && @account.registration_pin.present?
        @account.registration_pin
      else
        format("%06d", SecureRandom.random_number(1_000_000))
      end
    end

    def call(method, path, token: nil, body: nil, params: nil)
      response = connection.public_send(method, path) do |request|
        request.headers["Authorization"] = "Bearer #{token}" if token.present?
        request.params.update(params) if params
        request.body = body if body
      end
      interpret(response)
    end

    def interpret(response)
      data = response.body
      data = JSON.parse(data) if data.is_a?(String) && data.present?
      data = {} unless data.is_a?(Hash)
      return data if response.success? && data["success"] != false

      error = data["error"].is_a?(Hash) ? data["error"] : {}
      message = error["error_user_msg"].presence || error["message"].presence || "Meta rejected the request"
      raise Meta::Client::Error.new(message, code: error["code"], body: data)
    end

    def failure_message(error)
      return "#{error.message}. Reset the PIN in WhatsApp Manager, then try again." if error.code.to_s == "133005"

      error.message
    end

    def connection
      @connection ||= Faraday.new(url: "https://graph.facebook.com/#{ENV.fetch('META_GRAPH_VERSION', 'v26.0')}") do |builder|
        builder.request :json
        builder.response :json, content_type: /\bjson$/
        builder.options.timeout = 20
        builder.options.open_timeout = 8
      end
    end
  end
end
