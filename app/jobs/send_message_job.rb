class SendMessageJob < ApplicationJob
  queue_as :messages
  retry_on Meta::Client::RateLimitError, wait: :polynomially_longer, attempts: 5

  def perform(recipient_id)
    recipient = CampaignRecipient.find(recipient_id)
    return unless %w[pending queued].include?(recipient.status)

    campaign = recipient.campaign
    account = campaign.user.whatsapp_account
    result = Meta::Client.new(account).send_template_message(
      to: recipient.phone_number,
      template: campaign.template,
      parameters: campaign.parameters_for(recipient)
    )
    recipient.mark_sent!(result.dig("messages", 0, "id"))
    SimulateDeliveryJob.set(wait: 2.seconds).perform_later(recipient.id) if account&.demo_mode?
  rescue Meta::Client::RateLimitError
    raise
  rescue Meta::Client::Error => error
    recipient.mark_failed!(code: error.code, message: error.message)
  end
end
