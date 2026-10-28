class Campaign < ApplicationRecord
  STATUSES = %w[draft scheduled running completed failed].freeze

  belongs_to :user
  belongs_to :template
  has_many :recipients, class_name: "CampaignRecipient", dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  validate :template_belongs_to_user

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

  def template_belongs_to_user
    return if template.blank? || user_id.blank?
    return if template.user_id == user_id

    errors.add(:template, "must be one of your templates")
  end
end
