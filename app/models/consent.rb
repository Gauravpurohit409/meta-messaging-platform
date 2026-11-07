class Consent < ApplicationRecord
  SOURCES = %w[campaign_upload manual_entry inbound_message].freeze

  belongs_to :user

  before_validation { self.phone_number = PhoneNumbers.normalize(phone_number) }

  validates :phone_number, presence: true, uniqueness: { scope: :user_id }
  validates :source, inclusion: { in: SOURCES }
  validates :wording, :consented_at, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def self.record!(user:, phone_number:, source:, wording:)
    number = PhoneNumbers.normalize(phone_number)
    existing = find_by(user: user, phone_number: number)
    return existing if existing

    create!(user: user, phone_number: number, source: source, wording: wording, consented_at: Time.current)
  end

  def self.revoke!(user:, phone_number:, reason:)
    number = PhoneNumbers.normalize(phone_number)
    record = find_or_initialize_by(user: user, phone_number: number)
    record.source ||= "inbound_message"
    record.wording ||= "Opted out by message"
    record.consented_at ||= Time.current
    record.revoked_at ||= Time.current
    record.revoked_reason = reason if record.revoked_reason.blank?
    record.save!
    record
  end

  def self.restore!(user:, phone_number:)
    record = find_by(user: user, phone_number: PhoneNumbers.normalize(phone_number))
    record&.update!(revoked_at: nil, revoked_reason: nil)
    record
  end
end
