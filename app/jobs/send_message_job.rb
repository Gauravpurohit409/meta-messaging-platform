class SendMessageJob < ApplicationJob
  queue_as :messages
  retry_on Meta::Client::RateLimitError, wait: :polynomially_longer, attempts: 5

  def perform(recipient_id)
    recipient = CampaignRecipient.find(recipient_id)
    return unless %w[pending queued].include?(recipient.status)

    campaign = recipient.campaign
    account = campaign.user.whatsapp_account
    if account&.restricted?
      recipient.mark_failed!(code: nil, message: "This WhatsApp account is restricted")
      return
    end

    template = campaign.template_for(recipient)
    if template.category == "MARKETING" &&
        Consent.where(user_id: campaign.user_id, phone_number: recipient.phone_number).where.not(revoked_at: nil).exists?
      recipient.mark_failed!(code: "opted_out", message: "This person opted out of marketing messages")
      return
    end

    result = Meta::Client.new(account).send_template_message(
      to: recipient.phone_number,
      template: template,
      parameters: campaign.parameters_for(recipient)
    )
    recipient.mark_sent!(result.dig("messages", 0, "id"))
    SimulateDeliveryJob.set(wait: 2.seconds).perform_later(recipient.id) if account&.demo_mode?
  rescue Meta::Client::RateLimitError
    raise
  rescue Meta::Client::Error => error
    if error.code.to_s == "190"
      recipient.campaign.user.whatsapp_account.update!(reconnect_required: true)
    end
    recipient.mark_failed!(code: error.code, message: error.message)
  end
end
