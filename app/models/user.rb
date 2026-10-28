class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :whatsapp_account, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :campaigns, dependent: :destroy

  validates :name, presence: true, length: { maximum: 80 }
  validates :company, length: { maximum: 120 }, allow_blank: true

  after_create :provision_whatsapp_account

  private

  def provision_whatsapp_account
    create_whatsapp_account!(demo_mode: true) unless whatsapp_account
  end
end
