module Templates
  class Submitter
    def self.call(template)
      new(template).call
    end

    def initialize(template)
      @template = template
    end

    def call
      unless @template.editable?
        @template.errors.add(:base, "Only drafts and rejected templates can be submitted")
        return false
      end
      return false unless @template.valid?(:submit)

      account = @template.user.whatsapp_account
      result = Meta::Client.new(account).submit_template(@template)
      status = result["status"].to_s.downcase
      status = "pending" unless Template::STATUSES.include?(status)

      @template.update!(
        meta_template_id: result["id"].presence || @template.meta_template_id,
        status: status,
        category: result["category"].presence || @template.category,
        submitted_at: Time.current,
        rejection_reason: nil
      )

      if account&.demo_mode? && @template.pending?
        SimulateTemplateReviewJob.set(wait: 3.seconds).perform_later(@template.id)
      end
      true
    rescue Meta::Client::Error => error
      @template.errors.add(:base, error.message)
      false
    end
  end
end
