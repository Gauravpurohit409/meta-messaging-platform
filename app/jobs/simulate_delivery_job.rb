class SimulateDeliveryJob < ApplicationJob
  def perform(recipient_id)
    recipient = CampaignRecipient.find(recipient_id)
    return unless recipient.sent?
    return unless recipient.campaign.user.whatsapp_account&.demo_mode?

    if recipient.phone_number.end_with?("0000")
      recipient.mark_failed!(code: "131026", message: "Message undeliverable. Demo mode fails numbers that end in 0000.")
    else
      recipient.mark_delivered!
    end
  end
end
