class WhatsappAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token

  before_validation :ensure_verify_token

  validates :verify_token, presence: true
  validate :live_mode_has_credentials

  def live?
    !demo_mode? && access_token.present? && waba_id.present? && phone_number_id.present?
  end

  def regenerate_verify_token!
    update!(verify_token: SecureRandom.hex(16))
  end

  private

  def ensure_verify_token
    self.verify_token = SecureRandom.hex(16) if verify_token.blank?
  end

  def live_mode_has_credentials
    return if demo_mode?

    errors.add(:waba_id, "is required when demo mode is off") if waba_id.blank?
    errors.add(:phone_number_id, "is required when demo mode is off") if phone_number_id.blank?
    errors.add(:access_token, "is required when demo mode is off") if access_token.blank?
  end
end
