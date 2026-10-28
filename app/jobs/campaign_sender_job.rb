class CampaignSenderJob < ApplicationJob
  queue_as :campaigns

  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    return unless %w[running scheduled].include?(campaign.status)
    return if campaign.scheduled_at.present? && campaign.scheduled_at.future?

    unless campaign.template.approved?
      campaign.update!(
        status: "failed",
        failure_reason: "The template was no longer approved when the send started.",
        completed_at: Time.current
      )
      campaign.broadcast_progress
      return
    end

    campaign.update!(status: "running", started_at: campaign.started_at || Time.current)
    account = campaign.user.whatsapp_account
    gap = account&.demo_mode? ? 0.15 : 0.02

    campaign.recipients.where(status: "pending").find_each.with_index do |recipient, index|
      recipient.mark_queued!
      SendMessageJob.set(wait: index * gap).perform_later(recipient.id)
    end

    campaign.refresh_completion! if campaign.recipients.where(status: %w[pending queued]).none?
  end
end
