module Meta
  class MessagePayload
    def self.build(template:, to:, parameters:)
      parameters = parameters.to_h.stringify_keys
      components = []

      header_indexes = template.variable_indexes(template.header_text)
      if header_indexes.any?
        components << {
          type: "header",
          parameters: header_indexes.map { |number| text_param(parameters["header_#{number}"]) }
        }
      end

      body_indexes = template.variable_indexes(template.body)
      if body_indexes.any?
        components << {
          type: "body",
          parameters: body_indexes.map { |number| text_param(parameters["body_#{number}"]) }
        }
      end

      template.buttons.each_with_index do |button, index|
        next unless button["type"] == "URL" && button["url"].to_s.include?("{{")

        components << {
          type: "button",
          sub_type: "url",
          index: index.to_s,
          parameters: [ text_param(parameters["url_#{index}"]) ]
        }
      end

      payload = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: PhoneNumbers.normalize(to),
        type: "template",
        template: {
          name: template.name,
          language: { code: template.language }
        }
      }
      payload[:template][:components] = components if components.any?
      payload
    end

    def self.text_param(value)
      { type: "text", text: value.to_s }
    end
  end
end
