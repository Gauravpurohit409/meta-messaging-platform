module Meta
  class TemplatePayload
    def self.build(template)
      components = []

      if template.header_text.present?
        header = { type: "HEADER", format: "TEXT", text: template.header_text }
        indexes = template.variable_indexes(template.header_text)
        if indexes.any?
          header[:example] = { header_text: [ template.example_values["header_#{indexes.first}"].to_s ] }
        end
        components << header
      end

      body = { type: "BODY", text: template.body }
      body_indexes = template.variable_indexes(template.body)
      if body_indexes.any?
        body[:example] = {
          body_text: [ body_indexes.map { |number| template.example_values["body_#{number}"].to_s } ]
        }
      end
      components << body

      components << { type: "FOOTER", text: template.footer_text } if template.footer_text.present?

      if template.buttons.any?
        components << {
          type: "BUTTONS",
          buttons: template.buttons.each_with_index.map { |button, index| button_payload(button, template, index) }
        }
      end

      {
        name: template.name,
        language: template.language,
        category: template.category,
        allow_category_change: true,
        components: components
      }
    end

    def self.button_payload(button, template, index)
      case button["type"]
      when "QUICK_REPLY"
        { type: "QUICK_REPLY", text: button["text"] }
      when "URL"
        payload = { type: "URL", text: button["text"], url: button["url"] }
        payload[:example] = [ template.example_values["url_#{index}"].to_s ] if button["url"].to_s.include?("{{")
        payload
      when "PHONE_NUMBER"
        { type: "PHONE_NUMBER", text: button["text"], phone_number: "+#{button["phone_number"].to_s.gsub(/\D/, "")}" }
      end
    end
  end
end
