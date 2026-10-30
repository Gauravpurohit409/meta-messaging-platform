class Template < ApplicationRecord
  CATEGORY_OPTIONS = {
    "UTILITY" => {
      label: "Utility",
      description: "Orders, receipts, and account updates the customer already expects."
    },
    "MARKETING" => {
      label: "Marketing",
      description: "Offers, announcements, and re-engagement."
    },
    "AUTHENTICATION" => {
      label: "Authentication",
      description: "One-time passwords and login codes."
    }
  }.freeze
  CATEGORIES = CATEGORY_OPTIONS.keys.freeze
  STATUSES = %w[draft pending approved rejected paused disabled flagged archived].freeze
  LANGUAGES = {
    "en" => "English",
    "en_US" => "English (US)",
    "en_GB" => "English (UK)",
    "hi" => "Hindi",
    "bn" => "Bengali",
    "ta" => "Tamil",
    "te" => "Telugu",
    "mr" => "Marathi",
    "gu" => "Gujarati",
    "es" => "Spanish",
    "es_MX" => "Spanish (Mexico)",
    "pt_BR" => "Portuguese (Brazil)",
    "ar" => "Arabic",
    "id" => "Indonesian",
    "fr" => "French",
    "de" => "German"
  }.freeze
  BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER].freeze
  MAX_BUTTONS = 10

  belongs_to :user
  has_many :campaigns, dependent: :restrict_with_error

  scope :approved, -> { where(status: "approved") }

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: 512 },
    format: { with: /\A[a-z0-9_]+\z/, message: "can only use lowercase letters, numbers, and underscores" },
    uniqueness: { scope: [ :user_id, :language ], message: "already exists for this language" }
  validates :language, inclusion: { in: LANGUAGES.keys }
  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }
  validates :body, presence: true, length: { maximum: 1024 }
  validates :header_text, length: { maximum: 60 }, allow_blank: true
  validates :footer_text, length: { maximum: 60 }, allow_blank: true
  validate :header_variables_ok
  validate :body_variables_ok
  validate :footer_has_no_variables
  validate :buttons_ok
  validate :examples_cover_variables, on: :submit

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  def editable?
    status.in?(%w[draft rejected])
  end

  def approved?
    status == "approved"
  end

  def pending?
    status == "pending"
  end

  def rejected?
    status == "rejected"
  end

  def variable_indexes(text)
    text.to_s.scan(/\{\{(\d+)\}\}/).flatten.map(&:to_i)
  end

  def required_parameter_keys
    keys = variable_indexes(header_text).map { |number| "header_#{number}" }
    keys += variable_indexes(body).map { |number| "body_#{number}" }
    buttons.each_with_index do |button, index|
      keys << "url_#{index}" if button["type"] == "URL" && button["url"].to_s.match?(/\{\{\d+\}\}/)
    end
    keys
  end

  def language_name
    LANGUAGES.fetch(language, language)
  end

  def category_name
    CATEGORY_OPTIONS.dig(category, :label) || category.to_s.humanize
  end

  def campaign_option_label
    "#{name} · #{category_name}"
  end

  def parameter_label(key)
    case key.to_s
    when /\Aheader_(\d+)\z/ then "Header {{#{$1}}}"
    when /\Abody_(\d+)\z/ then "Body {{#{$1}}}"
    when /\Aurl_(\d+)\z/ then "Link button #{$1.to_i + 1}"
    else key.to_s
    end
  end

  private

  def normalize_fields
    self.name = name.to_s.strip.downcase
    self.header_text = header_text.to_s.strip.presence
    self.footer_text = footer_text.to_s.strip.presence
    self.body = body.to_s.strip
    self.buttons = Array(buttons).map { |button| button.to_h.stringify_keys }
    self.example_values = example_values.to_h.stringify_keys
  end

  def header_variables_ok
    check_variables(:header_text, max: 1)
  end

  def body_variables_ok
    check_variables(:body, max: nil)
    return if body.blank?

    words = body.gsub(/\{\{\d+\}\}/, " ").scan(/[[:alnum:]]+/).length
    variables = variable_indexes(body).size
    return unless variables.positive? && words < (variables * 2)

    errors.add(:body, "needs more fixed words around the variables so Meta can tell what the message is about")
  end

  def check_variables(attr, max:)
    text = send(attr).to_s
    return if text.blank?

    leftover = text.gsub(/\{\{\d+\}\}/, "")
    if leftover.include?("{{") || leftover.include?("}}")
      errors.add(attr, "variables must look like {{1}}, {{2}}, and so on")
      return
    end

    if text.strip.match?(/\A\{\{\d+\}\}/) || text.strip.match?(/\{\{\d+\}\}\s*\z/)
      errors.add(attr, "cannot start or end with a variable")
    end

    indexes = variable_indexes(text)
    return if indexes.empty?

    errors.add(attr, "can only include #{max} #{"variable".pluralize(max)}") if max && indexes.size > max

    expected = (1..indexes.max).to_a
    return if indexes == indexes.uniq && indexes.uniq.sort == expected

    errors.add(attr, "variables must be sequential, starting at {{1}}, with no gaps or repeats")
  end

  def footer_has_no_variables
    return if footer_text.blank?
    return unless footer_text.match?(/\{\{/)

    errors.add(:footer_text, "cannot contain variables")
  end

  def buttons_ok
    errors.add(:buttons, "are limited to #{MAX_BUTTONS}") if buttons.size > MAX_BUTTONS

    buttons.each_with_index do |button, index|
      label = "Button #{index + 1}"
      type = button["type"]
      unless BUTTON_TYPES.include?(type)
        errors.add(:buttons, "#{label} has an unknown type")
        next
      end

      text = button["text"].to_s
      if text.blank?
        errors.add(:buttons, "#{label} needs a label")
      elsif text.length > 25
        errors.add(:buttons, "#{label} label must be 25 characters or fewer")
      end

      case type
      when "URL"
        url = button["url"].to_s
        errors.add(:buttons, "#{label} needs an https link") unless url.match?(%r{\Ahttps://\S+\z})
        if url.scan(/\{\{\d+\}\}/).size > 1 || url.match?(/\{\{(?!1\}\})\d+\}\}/)
          errors.add(:buttons, "#{label} can only use {{1}} once in the link")
        end
      when "PHONE_NUMBER"
        digits = button["phone_number"].to_s.gsub(/\D/, "")
        errors.add(:buttons, "#{label} needs a phone number with a country code") unless digits.length.between?(8, 15)
      end
    end

    types = buttons.map { |button| button["type"] }
    quick_reply_indexes = types.each_index.select { |index| types[index] == "QUICK_REPLY" }
    return if quick_reply_indexes.empty? || types.uniq.length <= 1

    grouped_at_start = quick_reply_indexes == (0...quick_reply_indexes.size).to_a
    grouped_at_end = quick_reply_indexes == ((types.size - quick_reply_indexes.size)...types.size).to_a
    return if grouped_at_start || grouped_at_end

    errors.add(:buttons, "quick replies must sit together at the start or the end")
  end

  def examples_cover_variables
    required_parameter_keys.each do |key|
      errors.add(:base, "Add a sample for #{parameter_label(key)}") if example_values[key].blank?
    end
  end

  def broadcast_status_change
    broadcast_replace_to [ user, :templates ], target: self, partial: "templates/row", locals: { template: self }
    broadcast_replace_to self, target: "template_status_panel", partial: "templates/status_panel", locals: { template: self }
  rescue StandardError => error
    Rails.logger.warn("Template broadcast skipped: #{error.class}: #{error.message}")
  end
end
