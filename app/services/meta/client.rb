require "faraday"

module Meta
  class Client
    class Error < StandardError
      attr_reader :code, :body

      def initialize(message, code: nil, body: nil)
        super(message)
        @code = code
        @body = body
      end
    end

    class RateLimitError < Error; end

    GRAPH_VERSION = ENV.fetch("META_GRAPH_VERSION", "v26.0")
    RATE_LIMIT_CODES = %w[130429 80007 131048 131056].freeze

    def initialize(account)
      @account = account
    end

    def demo?
      @account.nil? || @account.demo_mode? || !@account.live?
    end

    def submit_template(template)
      if demo?
        return {
          "id" => template.meta_template_id.presence || "demo_#{SecureRandom.hex(6)}",
          "status" => "PENDING",
          "category" => template.category
        }
      end

      payload = TemplatePayload.build(template)
      if template.meta_template_id.present?
        post(template.meta_template_id, payload)
      else
        post("#{@account.waba_id}/message_templates", payload)
      end
    end

    def send_template_message(to:, template:, parameters:)
      if demo?
        return { "messages" => [ { "id" => "wamid.demo.#{SecureRandom.hex(12)}" } ] }
      end

      post(
        "#{@account.phone_number_id}/messages",
        MessagePayload.build(template: template, to: to, parameters: parameters)
      )
    end

    def delete_template(template)
      return true if demo?

      response = connection.delete("#{@account.waba_id}/message_templates") do |request|
        request.params["name"] = template.name
      end
      interpret(response)
      true
    end

    private

    def post(path, body)
      interpret(connection.post(path, body))
    rescue Faraday::Error => error
      raise Error.new("Could not reach Meta (#{error.message})")
    end

    def interpret(response)
      data = response.body
      data = JSON.parse(data) if data.is_a?(String) && data.present?
      data = {} unless data.is_a?(Hash)
      return data if response.success?

      error = data["error"].is_a?(Hash) ? data["error"] : {}
      code = error["code"]
      message = error["error_user_msg"].presence || error["message"].presence || "Meta rejected the request"
      if RATE_LIMIT_CODES.include?(code.to_s)
        raise RateLimitError.new(message, code: code, body: data)
      end

      raise Error.new(message, code: code, body: data)
    rescue JSON::ParserError
      raise Error.new("Meta returned a response Marquee could not read")
    end

    def connection
      @connection ||= Faraday.new(url: "https://graph.facebook.com/#{GRAPH_VERSION}") do |builder|
        builder.request :json
        builder.response :json, content_type: /\bjson$/
        builder.headers["Authorization"] = "Bearer #{@account.access_token}"
        builder.options.timeout = 20
        builder.options.open_timeout = 8
        builder.adapter Faraday.default_adapter
      end
    end
  end
end
