class Campaign < ApplicationRecord
  STATUSES = %w[draft scheduled running completed failed].freeze
  # North America per-delivered-message rates from the October 2026 R&D note.
  DELIVERY_RATES = {
    "MARKETING" => BigDecimal("0.02875"),
    "UTILITY" => BigDecimal("0.00391"),
    "AUTHENTICATION" => BigDecimal("0.00391")
  }.freeze

  belongs_to :user
  belongs_to :template
  belongs_to :variant_template, class_name: "Template", optional: true
  has_many :recipients, class_name: "CampaignRecipient", dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  validate :template_belongs_to_user
  validate :variant_template_matches

  def draft?
    status == "draft"
  end

  def scheduled?
    status == "scheduled"
  end

  def running?
    status == "running"
  end

  def parameters_for(recipient)
    default_parameters.to_h.stringify_keys.merge(recipient.parameters.to_h.stringify_keys.compact_blank)
  end

  # Recipients still waiting to be handed to WhatsApp. Delivery and read
  # receipts arrive after this, so they are not part of the queue.
  def dispatched_count
    total_recipients - recipients.where(status: %w[pending queued]).count
  end

  def estimated_delivery_cost
    DELIVERY_RATES.fetch(template.category, BigDecimal("0")) * delivered_count
  end

  def high_failure_rate?
    total_recipients >= 5 && failed_count * 5 >= total_recipients
  end

  def template_for(recipient)
    recipient.variant == "b" && variant_template ? variant_template : template
  end

  def assign_variants!
    if variant_template_id.blank?
      recipients.update_all(variant: nil)
      return
    end

    recipients.order(:id).each_with_index do |recipient, index|
      recipient.update_column(:variant, index.even? ? "a" : "b")
    end
  end

  def refresh_completion!
    reload
    broadcast_progress
    return unless running?
    return if recipients.where(status: %w[pending queued]).exists?

    update!(status: "completed", completed_at: Time.current)
    broadcast_progress
  end

  def broadcast_progress
    broadcast_replace_to self, target: "campaign_stats", partial: "campaigns/stats", locals: { campaign: self }
  rescue StandardError => error
    Rails.logger.warn("Campaign broadcast skipped: #{error.class}: #{error.message}")
  end

  private

  def variant_template_matches
    return if variant_template.blank?

    errors.add(:variant_template, "must be one of your templates") if user_id.present? && variant_template.user_id != user_id
    errors.add(:variant_template, "must be a different template") if variant_template_id == template_id
    return if template.blank?

    errors.add(:variant_template, "must be the same type as version A") if variant_template.category != template.category
    if variant_template.required_parameter_keys != template.required_parameter_keys
      errors.add(:variant_template, "must use the same variables as version A")
    end
  end

  def template_belongs_to_user
    return if template.blank? || user_id.blank?
    return if template.user_id == user_id

    errors.add(:template, "must be one of your templates")
  end
end
