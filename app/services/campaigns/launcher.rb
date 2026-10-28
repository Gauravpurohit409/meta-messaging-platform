module Campaigns
  class Launcher
    def self.call(campaign, scheduled_at: nil)
      new(campaign, scheduled_at: scheduled_at).call
    end

    def initialize(campaign, scheduled_at:)
      @campaign = campaign
      @scheduled_at = scheduled_at
    end

    def call
      launched = false
      @campaign.with_lock do
        unless @campaign.draft?
          @campaign.errors.add(:base, "This campaign has already been launched")
          next
        end
        unless @campaign.template.approved?
          @campaign.errors.add(:base, "The template has to be approved before you can send it")
          next
        end
        if @campaign.recipients.none?
          @campaign.errors.add(:base, "Add at least one recipient")
          next
        end

        missing = missing_parameters
        if missing.any?
          missing.first(5).each { |message| @campaign.errors.add(:base, message) }
          next
        end

        if @scheduled_at.present? && @scheduled_at.future?
          @campaign.update!(status: "scheduled", scheduled_at: @scheduled_at, failure_reason: nil)
          CampaignSenderJob.set(wait_until: @scheduled_at).perform_later(@campaign.id)
        else
          @campaign.update!(status: "running", started_at: Time.current, scheduled_at: nil, failure_reason: nil)
          CampaignSenderJob.perform_later(@campaign.id)
        end
        launched = true
      end
      launched
    end

    private

    def missing_parameters
      keys = @campaign.template.required_parameter_keys
      @campaign.recipients.flat_map do |recipient|
        merged = @campaign.parameters_for(recipient)
        keys.filter_map do |key|
          next if merged[key].present?

          "#{recipient.phone_number} is missing #{@campaign.template.parameter_label(key)}"
        end
      end
    end
  end
end
