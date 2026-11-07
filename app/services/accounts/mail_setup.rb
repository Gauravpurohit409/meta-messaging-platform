module Accounts
  module MailSetup
    module_function

    def confirmation_required?
      return true unless Rails.env.production?

      ENV["SMTP_ADDRESS"].present?
    end

    def apply!
      return if confirmation_required?

      Devise.allow_unconfirmed_access_for = nil
      Rails.logger.warn("SMTP_ADDRESS is blank, so new accounts can sign in without confirming their email. Set SMTP_ADDRESS before requiring confirmation.")
    end
  end
end
