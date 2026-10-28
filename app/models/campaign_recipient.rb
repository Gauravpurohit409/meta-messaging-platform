class CampaignRecipient < ApplicationRecord
  STATUSES = %w[pending queued sent delivered read failed].freeze

  belongs_to :campaign

  validates :phone_number, presence: true, uniqueness: { scope: :campaign_id }
  validates :status, inclusion: { in: STATUSES }

  def pending?
    status == "pending"
  end

  def sent?
    status == "sent"
  end

  def failed?
    status == "failed"
  end

  def mark_queued!
    return unless pending?

    update!(status: "queued")
    broadcast_row
  end

  def mark_sent!(message_id)
    return if %w[sent delivered read failed].include?(status)

    update!(status: "sent", message_id: message_id, sent_at: Time.current, error_code: nil, error_message: nil)
    Campaign.update_counters(campaign_id, sent_count: 1)
    broadcast_row
    campaign.reload.broadcast_progress
  end

  def mark_delivered!
    return if %w[delivered read].include?(status)

    update!(status: "delivered", delivered_at: Time.current)
    Campaign.update_counters(campaign_id, delivered_count: 1)
    broadcast_row
    campaign.refresh_completion!
  end

  def mark_read!
    return if status == "read"

    already_delivered = %w[delivered read].include?(status)
    update!(status: "read", read_at: Time.current, delivered_at: delivered_at || Time.current)
    Campaign.update_counters(campaign_id, read_count: 1)
    Campaign.update_counters(campaign_id, delivered_count: 1) unless already_delivered
    broadcast_row
    campaign.refresh_completion!
  end

  def mark_failed!(code:, message:)
    return if failed?

    update!(status: "failed", error_code: code.to_s.presence, error_message: message)
    Campaign.update_counters(campaign_id, failed_count: 1)
    broadcast_row
    campaign.refresh_completion!
  end

  private

  def broadcast_row
    broadcast_replace_to campaign, target: self, partial: "campaigns/recipient", locals: { recipient: self }
  rescue StandardError => error
    Rails.logger.warn("Recipient broadcast skipped: #{error.class}: #{error.message}")
  end
end
