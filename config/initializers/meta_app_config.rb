Rails.application.config.after_initialize do
  Devise.mailer_sender = "#{Meta::AppConfig.display_name} <desk@marquee.test>"
end
