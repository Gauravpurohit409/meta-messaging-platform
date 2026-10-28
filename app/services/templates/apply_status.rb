module Templates
  class ApplyStatus
    EVENTS = {
      "APPROVED" => "approved",
      "REJECTED" => "rejected",
      "PENDING" => "pending",
      "PAUSED" => "paused",
      "DISABLED" => "disabled",
      "FLAGGED" => "flagged",
      "ARCHIVED" => "archived",
      "REINSTATED" => "approved",
      "PENDING_DELETION" => "archived",
      "DELETED" => "archived"
    }.freeze

    def self.call(payload)
      value = payload["value"] || payload
      template = find_template(value)
      return if template.nil?

      status = EVENTS[value["event"].to_s] || value["event"].to_s.downcase
      return unless Template::STATUSES.include?(status)

      attributes = { status: status }
      if status == "rejected"
        reason = [ value["reason"], value.dig("rejection_info", "reason"), value.dig("rejection_info", "recommendation") ]
        attributes[:rejection_reason] = reason.compact_blank.join(" — ").presence
      end
      attributes[:approved_at] = Time.current if status == "approved" && template.approved_at.blank?
      attributes[:category] = value["message_template_category"] if value["message_template_category"].present? && Template::CATEGORIES.include?(value["message_template_category"])
      template.update!(attributes)
    end

    def self.find_template(value)
      id = value["message_template_id"].to_s
      return Template.find_by(meta_template_id: id) if id.present?

      name = value["message_template_name"]
      raw_language = value["message_template_language"].to_s
      Template.find_by(name: name, language: raw_language.tr("-", "_")) ||
        Template.find_by(name: name, language: raw_language)
    end
  end
end
