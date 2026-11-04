require "rails_helper"

RSpec.describe "Meta::AppConfig" do
  let(:config_keys) { %w[META_APP_ID META_EMBEDDED_SIGNUP_CONFIG_ID META_APP_SECRET META_APP_DISPLAY_NAME] }

  around do |example|
    saved = config_keys.to_h { |key| [ key, ENV[key] ] }
    config_keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  describe ".login_permissions" do
    it "requests the two WhatsApp permissions Embedded Signup needs" do
      expect(Meta::AppConfig.login_permissions).to contain_exactly(
        "whatsapp_business_management",
        "whatsapp_business_messaging"
      )
    end

    it "does not request business_management, which the app does not use" do
      expect(Meta::AppConfig.login_permissions).not_to include("business_management")
    end

    it "lists each permission only once" do
      expect(Meta::AppConfig.login_permissions.uniq).to eq(Meta::AppConfig.login_permissions)
    end

    it "returns a frozen list so callers cannot widen the request" do
      expect(Meta::AppConfig.login_permissions).to be_frozen
    end
  end

  describe ".login_scope" do
    it "joins the permissions with commas and no spaces, as the login dialog expects" do
      expect(Meta::AppConfig.login_scope).to eq("whatsapp_business_management,whatsapp_business_messaging")
    end
  end

  describe ".display_name" do
    it "defaults to Marquee when META_APP_DISPLAY_NAME is not set" do
      expect(Meta::AppConfig.display_name).to eq("Marquee")
    end

    it "uses META_APP_DISPLAY_NAME, trimmed of surrounding spaces" do
      ENV["META_APP_DISPLAY_NAME"] = "  Northwind Desk  "

      expect(Meta::AppConfig.display_name).to eq("Northwind Desk")
    end

    it "falls back to Marquee when META_APP_DISPLAY_NAME is blank" do
      ENV["META_APP_DISPLAY_NAME"] = "   "

      expect(Meta::AppConfig.display_name).to eq("Marquee")
    end

    [ "Meta Desk", "meta-desk", "MARQUEE META", "WhatsApp Campaigns", "whatsapp_desk", "Facebook Shop" ].each do |name|
      it "rejects \"#{name}\" because Meta's brand names cannot appear in the app name" do
        ENV["META_APP_DISPLAY_NAME"] = name

        expect { Meta::AppConfig.display_name }.to raise_error(Meta::AppConfig::InvalidDisplayName)
      end
    end
  end

  describe ".embedded_signup_ready?" do
    it "is false when nothing is configured" do
      expect(Meta::AppConfig.embedded_signup_ready?).to be(false)
    end

    it "is false when only the app id is set" do
      ENV["META_APP_ID"] = "1234567890"

      expect(Meta::AppConfig.embedded_signup_ready?).to be(false)
    end

    it "is false when the Embedded Signup configuration id is missing" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_APP_SECRET"] = "secret"

      expect(Meta::AppConfig.embedded_signup_ready?).to be(false)
    end

    it "is false when the app secret is missing" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"

      expect(Meta::AppConfig.embedded_signup_ready?).to be(false)
    end

    it "is false when a required value is only whitespace" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "   "
      ENV["META_APP_SECRET"] = "secret"

      expect(Meta::AppConfig.embedded_signup_ready?).to be(false)
    end

    it "is true when the app id, configuration id and app secret are all set" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"
      ENV["META_APP_SECRET"] = "secret"

      expect(Meta::AppConfig.embedded_signup_ready?).to be(true)
    end
  end

  describe "configuration documentation" do
    it "lists the new variables in .env.example so deploys know to set them" do
      example = File.read(Rails.root.join(".env.example"))

      %w[META_APP_ID META_EMBEDDED_SIGNUP_CONFIG_ID META_APP_DISPLAY_NAME].each do |key|
        expect(example).to match(/^#{key}=/)
      end
    end
  end
end
