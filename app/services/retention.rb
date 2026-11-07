module Retention
  module_function

  def webhook_days
    positive_integer("RETENTION_WEBHOOK_DAYS", 30)
  end

  def recipient_days
    positive_integer("RETENTION_RECIPIENT_DAYS", 180)
  end

  def purge!(now: Time.current)
    webhooks = WebhookEvent.where("created_at < ?", now - webhook_days.days).delete_all
    stale = Campaign.where(status: %w[completed failed]).where("completed_at < ?", now - recipient_days.days)
    recipients = CampaignRecipient.where(campaign_id: stale.select(:id)).delete_all
    { webhook_events: webhooks, campaign_recipients: recipients }
  end

  def positive_integer(key, default)
    value = ENV[key].to_i
    value.positive? ? value : default
  end
end
