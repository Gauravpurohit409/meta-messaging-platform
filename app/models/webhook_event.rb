class WebhookEvent < ApplicationRecord
  validates :event_type, presence: true
end
