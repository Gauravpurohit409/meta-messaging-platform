class DataDeletionRequest < ApplicationRecord
  before_validation { self.confirmation_code ||= SecureRandom.hex(8) }

  validates :confirmation_code, presence: true, uniqueness: true
end
