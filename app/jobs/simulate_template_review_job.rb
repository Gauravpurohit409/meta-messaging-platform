class SimulateTemplateReviewJob < ApplicationJob
  def perform(template_id)
    template = Template.find(template_id)
    return unless template.pending?
    return unless template.user.whatsapp_account&.demo_mode?

    if template.body.match?(/legal action|scam|you have won/i) || template.name.include?("reject")
      template.update!(
        status: "rejected",
        rejection_reason: "ABUSIVE_CONTENT — this demo review rejects threats, scam wording, and template names that include \"reject\"."
      )
    else
      template.update!(status: "approved", approved_at: Time.current, rejection_reason: nil)
    end
  end
end
