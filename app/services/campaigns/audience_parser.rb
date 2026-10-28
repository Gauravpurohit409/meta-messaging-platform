require "csv"

module Campaigns
  class AudienceParser
    MAX_RECIPIENTS = 500
    Result = Struct.new(:recipients, :errors, keyword_init: true)
    Row = Struct.new(:phone, :parameters, keyword_init: true)

    def self.call(text:, file: nil)
      new(text: text, file: file).call
    end

    def initialize(text:, file:)
      @text = text.to_s
      @file = file
    end

    def call
      rows = []
      errors = []

      if @file.respond_to?(:read)
        contents = @file.read
        contents = contents.dup.force_encoding("UTF-8") if contents.respond_to?(:force_encoding)
        rows.concat(parse_csv(contents.to_s, errors))
      end

      if @text.present?
        if csv_text?(@text)
          rows.concat(parse_csv(@text, errors))
        else
          @text.each_line do |line|
            next if line.strip.blank?

            phone = PhoneNumbers.normalize(line)
            if PhoneNumbers.valid?(phone)
              rows << Row.new(phone: phone, parameters: {})
            else
              errors << "#{line.strip} is not a phone number with a country code"
            end
          end
        end
      end

      deduped = []
      seen = {}
      rows.each do |row|
        if seen[row.phone]
          errors << "#{row.phone} is listed more than once"
          next
        end
        seen[row.phone] = true
        deduped << row
      end

      errors << "A campaign can include up to #{MAX_RECIPIENTS} people" if deduped.size > MAX_RECIPIENTS
      Result.new(recipients: deduped, errors: errors.uniq)
    end

    private

    def csv_text?(text)
      first = text.lines.first.to_s
      first.downcase.include?("phone") && first.include?(",")
    end

    def parse_csv(raw, errors)
      table = CSV.parse(raw.to_s.sub("\uFEFF", ""), headers: true, skip_blanks: true)
      phone_header = table.headers.compact.find { |header| header.to_s.strip.casecmp("phone").zero? }
      if phone_header.nil?
        errors << "The CSV needs a phone column"
        return []
      end

      table.filter_map do |csv_row|
        phone = PhoneNumbers.normalize(csv_row[phone_header])
        next if phone.blank?

        unless PhoneNumbers.valid?(phone)
          errors << "#{csv_row[phone_header]} is not a phone number with a country code"
          next
        end

        parameters = {}
        csv_row.headers.each do |header|
          next if header.blank? || header.to_s.strip.casecmp("phone").zero?

          value = csv_row[header].to_s.strip
          next if value.blank?

          key = header.to_s.strip
          key = "body_#{key}" if key.match?(/\A\d+\z/)
          parameters[key] = value
        end
        Row.new(phone: phone, parameters: parameters)
      end
    rescue CSV::MalformedCSVError => error
      errors << "Could not read that CSV (#{error.message})"
      []
    end
  end
end
