class InboundMessage < ApplicationRecord
  belongs_to :whatsapp_account

  validates :wa_message_id, :from_number, :received_at, presence: true
  validates :wa_message_id, uniqueness: true
end
