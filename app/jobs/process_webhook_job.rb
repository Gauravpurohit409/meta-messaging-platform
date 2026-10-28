class ProcessWebhookJob < ApplicationJob
  def perform(event_id)
    event = WebhookEvent.find(event_id)
    case event.event_type
    when "message_template_status_update"
      Templates::ApplyStatus.call(event.payload)
    when "messages"
      Campaigns::ApplyMessageStatus.call(event.payload)
    end
    event.update!(processed: true, error_message: nil)
  rescue StandardError => error
    event&.update(error_message: error.message)
    raise
  end
end
