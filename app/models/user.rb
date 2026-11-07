class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable

  before_destroy :disconnect_from_meta

  has_one :whatsapp_account, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :consents, dependent: :destroy
  has_many :inbound_messages, through: :whatsapp_account

  validates :name, presence: true, length: { maximum: 80 }
  validates :company, length: { maximum: 120 }, allow_blank: true

  after_create :provision_whatsapp_account

  private

  def provision_whatsapp_account
    create_whatsapp_account!(demo_mode: true) unless whatsapp_account
  end

  def disconnect_from_meta
    account = whatsapp_account
    return if account.nil? || account.demo_mode? || account.access_token.blank?

    Meta::EmbeddedSignup.disconnect(account)
  rescue StandardError => error
    Rails.logger.warn("Meta disconnect skipped during account deletion: #{error.class}")
  end
end
