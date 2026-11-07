class WhatsappAccount < ApplicationRecord
  belongs_to :user
  has_many :inbound_messages, dependent: :destroy

  encrypts :access_token
  encrypts :registration_pin

  before_validation :ensure_verify_token, :nilify_blank_ids

  validates :verify_token, presence: true
  validates :waba_id, uniqueness: { allow_nil: true, message: "is already connected to another desk" }
  validates :phone_number_id, uniqueness: { allow_nil: true, message: "is already connected to another desk" }
  validate :live_mode_has_credentials

  def live?
    !demo_mode? && !restricted? && access_token.present? && waba_id.present? && phone_number_id.present?
  end

  def release_meta_connection!
    update!(
      demo_mode: true,
      access_token: nil,
      waba_id: nil,
      phone_number_id: nil,
      business_name: nil,
      quality_rating: nil,
      messaging_limit: nil,
      pin_phone_number_id: phone_number_id.presence || pin_phone_number_id,
      restricted: false,
      reconnect_required: false,
      policy_notice: nil,
      connected_at: nil
    )
  end

  def regenerate_verify_token!
    update!(verify_token: SecureRandom.hex(16))
  end

  private

  def ensure_verify_token
    self.verify_token = SecureRandom.hex(16) if verify_token.blank?
  end

  def nilify_blank_ids
    self.waba_id = nil if waba_id.blank?
    self.phone_number_id = nil if phone_number_id.blank?
  end

  def live_mode_has_credentials
    return if demo_mode?

    errors.add(:waba_id, "is required when demo mode is off") if waba_id.blank?
    errors.add(:phone_number_id, "is required when demo mode is off") if phone_number_id.blank?
    errors.add(:access_token, "is required when demo mode is off") if access_token.blank?
  end
end
