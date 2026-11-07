# Be sure to restart your server when you modify this file.

# Embedded Signup loads connect.facebook.net and opens a Facebook frame.
# The stylesheet imports Google fonts, and a few views use inline style attributes.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.script_src :self, "https://connect.facebook.net"
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, "https://www.facebook.com", "https://connect.facebook.net"
    policy.frame_src "https://www.facebook.com", "https://web.facebook.com"
    policy.connect_src :self, "https://www.facebook.com", "https://web.facebook.com", "https://connect.facebook.net", "https://graph.facebook.com"
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
