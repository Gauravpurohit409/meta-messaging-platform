class TemplatesController < ApplicationController
  before_action :set_template, only: %i[show edit update submit duplicate destroy]

  def index
    @status = params[:status].presence_in(Template::STATUSES)
    @category = params[:category].presence_in(Template::CATEGORIES)
    scope = current_user.templates.order(updated_at: :desc)
    scope = scope.where(status: @status) if @status
    scope = scope.where(category: @category) if @category
    if params[:q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      scope = scope.where("name ILIKE :q OR body ILIKE :q", q: query)
    end
    @templates = scope
    @counts = current_user.templates.group(:status).count
  end

  def show
  end

  def new
    @template = current_user.templates.new(language: "en_US", category: "UTILITY", buttons: [])
  end

  def edit
    return if @template.editable?

    redirect_to @template, alert: "This template is locked while Meta has it. Duplicate it to draft a new version."
  end

  def create
    @template = current_user.templates.new(template_attributes)
    if @template.save
      redirect_to @template, notice: "Draft saved. Submit it when the samples look right."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    unless @template.editable?
      redirect_to @template, alert: "This template can no longer be edited."
      return
    end

    if @template.update(template_attributes)
      redirect_to @template, notice: "Draft updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    if Templates::Submitter.call(@template)
      notice = if current_user.whatsapp_account.demo_mode?
        "Submitted. Demo review finishes in a few seconds."
      else
        "Submitted to Meta. Review usually finishes within a day."
      end
      redirect_to @template, notice: notice
    else
      redirect_to @template, alert: @template.errors.full_messages.to_sentence
    end
  end

  def duplicate
    copy = @template.dup
    copy.name = duplicate_name(@template)
    copy.status = "draft"
    copy.meta_template_id = nil
    copy.submitted_at = nil
    copy.approved_at = nil
    copy.rejection_reason = nil
    copy.save!
    redirect_to edit_template_path(copy), notice: "A draft copy is ready."
  end

  def destroy
    unless @template.editable?
      redirect_to @template, alert: "Approved and in-review templates stay on the desk. Duplicate one if you need a new version."
      return
    end
    if @template.campaigns.exists?
      redirect_to @template, alert: "A campaign still uses this template."
      return
    end

    Meta::Client.new(current_user.whatsapp_account).delete_template(@template) if @template.meta_template_id.present?
    @template.destroy!
    redirect_to templates_path, notice: "Template deleted."
  rescue Meta::Client::Error => error
    redirect_to @template, alert: error.message
  end

  private

  def set_template
    @template = current_user.templates.find(params[:id])
  end

  def template_attributes
    params.require(:template).permit(:name, :language, :category, :header_text, :body, :footer_text).to_h.merge(
      buttons: extracted_buttons,
      example_values: extracted_examples
    )
  end

  def extracted_buttons
    raw = params.dig(:template, :buttons)
    return [] unless raw.respond_to?(:values)

    raw.values.filter_map do |button|
      next unless button.respond_to?(:permit)

      data = button.permit(:type, :text, :url, :phone_number).to_h.stringify_keys
      next if data["type"].blank?

      data
    end
  end

  def extracted_examples
    raw = params.dig(:template, :example_values)
    return {} unless raw.respond_to?(:each)

    raw.to_unsafe_h.each_with_object({}) do |(key, value), memo|
      next unless key.to_s.match?(/\A(body|header|url)_\d+\z/)

      cleaned = value.to_s.strip
      memo[key.to_s] = cleaned if cleaned.present?
    end
  end

  def duplicate_name(template)
    base = template.name.sub(/_copy\d*\z/, "")
    candidate = "#{base}_copy"
    suffix = 2
    while current_user.templates.exists?(name: candidate, language: template.language)
      candidate = "#{base}_copy#{suffix}"
      suffix += 1
    end
    candidate.first(512)
  end
end
