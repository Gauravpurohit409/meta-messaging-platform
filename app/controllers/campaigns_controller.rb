require "csv"

class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show launch cancel destroy]

  def index
    @campaigns = current_user.campaigns.includes(:template).order(updated_at: :desc)
  end

  def new
    @approved_templates = current_user.templates.approved.order(:name)
    @template = @approved_templates.find_by(id: params[:template_id]) || @approved_templates.first
    @campaign = current_user.campaigns.new(name: default_campaign_name)
  end

  def create
    @approved_templates = current_user.templates.approved.order(:name)
    @template = @approved_templates.find_by(id: params.dig(:campaign, :template_id))
    @campaign = current_user.campaigns.new(name: params.dig(:campaign, :name))
    @campaign.template = @template if @template

    if @template.nil?
      @template = @approved_templates.first
      @campaign.errors.add(:template, "must be an approved template")
      render :new, status: :unprocessable_entity
      return
    end

    parsed = Campaigns::AudienceParser.call(text: params[:audience_text], file: params[:audience_file])
    defaults = default_parameters_for(@template)
    saved = false

    Campaign.transaction do
      @campaign.default_parameters = defaults
      @campaign.total_recipients = parsed.errors.any? ? 0 : parsed.recipients.size
      valid = @campaign.valid?
      parsed.errors.each { |message| @campaign.errors.add(:base, message) }
      if parsed.recipients.empty? && parsed.errors.empty?
        @campaign.errors.add(:base, "Add at least one phone number")
      end
      raise ActiveRecord::Rollback unless valid && parsed.errors.empty? && parsed.recipients.any?

      @campaign.save!
      parsed.recipients.each do |row|
        @campaign.recipients.create!(phone_number: row.phone, parameters: row.parameters)
      end
      @campaign.update!(total_recipients: parsed.recipients.size)
      saved = true
    end

    if saved
      redirect_to @campaign, notice: "Campaign saved as a draft. Launch it when the audience looks right."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @recipients = @campaign.recipients.order(:id)
  end

  def sample
    template = current_user.templates.approved.find(params[:template_id])
    headers = [ "phone" ] + template.required_parameter_keys
    csv = CSV.generate do |out|
      out << headers
      out << [ "919800011111", *template.required_parameter_keys.map { |key| template.example_values[key] } ]
    end
    send_data csv, filename: "#{template.name}_audience.csv", type: "text/csv"
  end

  def launch
    scheduled_at = parsed_schedule
    if Campaigns::Launcher.call(@campaign, scheduled_at: scheduled_at)
      @campaign.reload
      notice = @campaign.scheduled? ? "Campaign scheduled for #{view_context.stamp(@campaign.scheduled_at)}." : "Campaign is sending."
      redirect_to @campaign, notice: notice
    else
      @recipients = @campaign.recipients.order(:id)
      render :show, status: :unprocessable_entity
    end
  end

  def cancel
    @campaign.with_lock do
      if @campaign.scheduled?
        @campaign.update!(status: "draft", scheduled_at: nil)
      else
        @campaign.errors.add(:base, "Only a scheduled campaign can be pulled back")
      end
    end

    if @campaign.errors.empty? && @campaign.draft?
      redirect_to @campaign, notice: "Schedule cleared. The campaign is a draft again."
    else
      redirect_to @campaign, alert: @campaign.errors.full_messages.to_sentence.presence || "Could not cancel the schedule."
    end
  end

  def destroy
    unless @campaign.draft?
      redirect_to @campaign, alert: "Only drafts can be deleted."
      return
    end

    @campaign.destroy!
    redirect_to campaigns_path, notice: "Draft deleted."
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.includes(:template).find(params[:id])
  end

  def parsed_schedule
    return if params[:scheduled_at].blank?

    Time.zone.parse(params[:scheduled_at])
  rescue ArgumentError
    nil
  end

  def default_campaign_name
    return "" if @template.nil?

    "#{@template.name.tr("_", " ").capitalize} · #{Time.zone.today.strftime("%-d %b")}"
  end

  def default_parameters_for(template)
    raw = params[:default_parameters]
    return {} unless raw.respond_to?(:each)

    allowed = template.required_parameter_keys
    raw.to_unsafe_h.slice(*allowed).each_with_object({}) do |(key, value), memo|
      cleaned = value.to_s.strip
      memo[key] = cleaned if cleaned.present?
    end
  end
end
