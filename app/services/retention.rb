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
    inbound = InboundMessage.where("received_at < ?", now - webhook_days.days).delete_all
    cutoff = now - recipient_days.days
    stale = Campaign.where(status: %w[completed failed]).where("COALESCE(completed_at, updated_at) < ?", cutoff)
    recipients = CampaignRecipient.where(campaign_id: stale.select(:id)).delete_all
    { webhook_events: webhooks, inbound_messages: inbound, campaign_recipients: recipients }
  end

  def positive_integer(key, default)
    value = ENV[key].to_i
    value.positive? ? value : default
  end
end
