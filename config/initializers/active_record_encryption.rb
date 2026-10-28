# Stable development fallbacks keep the demo bootable. Set real keys in production.
def marquee_encryption_key(name, fallback)
  value = ENV[name].to_s
  value.present? ? value : fallback
end

Rails.application.config.active_record.encryption.primary_key =
  marquee_encryption_key("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "marquee-dev-primary-key-32b!!")
Rails.application.config.active_record.encryption.deterministic_key =
  marquee_encryption_key("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "marquee-dev-deterministic-key!!")
Rails.application.config.active_record.encryption.key_derivation_salt =
  marquee_encryption_key("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", "marquee-dev-key-derivation-salt")
