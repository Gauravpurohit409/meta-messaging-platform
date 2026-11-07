Rails.application.config.after_initialize do
  Accounts::MailSetup.apply!
end
