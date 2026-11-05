require "rails_helper"
require "open3"

RSpec.describe Meta::AppConfig do
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
      expect(described_class.login_permissions).to contain_exactly(
        "whatsapp_business_management",
        "whatsapp_business_messaging"
      )
    end

    it "does not request business_management, which the app does not use" do
      expect(described_class.login_permissions).not_to include("business_management")
    end

    it "lists each permission only once" do
      expect(described_class.login_permissions.uniq).to eq(described_class.login_permissions)
    end

    it "returns a frozen list so callers cannot widen the request" do
      expect(described_class.login_permissions).to be_frozen
    end

    it "freezes each permission name so callers cannot change the scope in place" do
      expect(described_class.login_permissions).to all(be_frozen)
    end

    it "raises when a caller tries to edit a permission name in place" do
      expect { described_class.login_permissions.first << "x" }.to raise_error(FrozenError)
    end
  end

  describe ".login_scope" do
    it "joins the permissions with commas and no spaces, as the login dialog expects" do
      expect(described_class.login_scope).to eq("whatsapp_business_management,whatsapp_business_messaging")
    end
  end

  describe ".display_name" do
    it "defaults to Marquee when META_APP_DISPLAY_NAME is not set" do
      expect(described_class.display_name).to eq("Marquee")
    end

    it "uses META_APP_DISPLAY_NAME, trimmed of surrounding spaces" do
      ENV["META_APP_DISPLAY_NAME"] = "  Northwind Desk  "

      expect(described_class.display_name).to eq("Northwind Desk")
    end

    it "falls back to Marquee when META_APP_DISPLAY_NAME is blank" do
      ENV["META_APP_DISPLAY_NAME"] = "   "

      expect(described_class.display_name).to eq("Marquee")
    end

    [ "Meta Desk", "meta-desk", "MARQUEE META", "WhatsApp Campaigns", "whatsapp_desk", "Facebook Shop", "Meta's Desk", "Marquee for Meta" ].each do |name|
      it "rejects \"#{name}\" because Meta's brand names cannot appear as a word in the app name" do
        ENV["META_APP_DISPLAY_NAME"] = name

        expect { described_class.display_name }.to raise_error(described_class::InvalidDisplayName)
      end
    end

    it "explains which brand words are reserved when it rejects a name" do
      ENV["META_APP_DISPLAY_NAME"] = "Meta Desk"

      expect { described_class.display_name }.to raise_error(
        described_class::InvalidDisplayName,
        /Meta, WhatsApp or Facebook/
      )
    end

    [ "Metaphor Desk", "Metaverse Shop", "Northwind Desk", "Facebookish", "Meta2 Desk", "2Meta Desk" ].each do |name|
      it "accepts \"#{name}\" because the brand name is only part of a longer word" do
        ENV["META_APP_DISPLAY_NAME"] = name

        expect(described_class.display_name).to eq(name)
      end
    end
  end

  describe ".app_id" do
    it "is nil when META_APP_ID is not set" do
      expect(described_class.app_id).to be_nil
    end

    it "returns the id with surrounding spaces removed" do
      ENV["META_APP_ID"] = "  1234567890 "

      expect(described_class.app_id).to eq("1234567890")
    end

    it "is nil when the value is not a numeric Meta app id" do
      ENV["META_APP_ID"] = "abc def"

      expect(described_class.app_id).to be_nil
    end
  end

  describe ".embedded_signup_configuration_id" do
    it "is nil when META_EMBEDDED_SIGNUP_CONFIG_ID is not set" do
      expect(described_class.embedded_signup_configuration_id).to be_nil
    end

    it "returns the id with surrounding spaces removed" do
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = " 987654321 "

      expect(described_class.embedded_signup_configuration_id).to eq("987654321")
    end

    it "is nil when the value is not numeric" do
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "config-1"

      expect(described_class.embedded_signup_configuration_id).to be_nil
    end
  end

  describe ".embedded_signup_ready?" do
    it "is false when nothing is configured" do
      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when only the app id is set" do
      ENV["META_APP_ID"] = "1234567890"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when the Embedded Signup configuration id is missing" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_APP_SECRET"] = "secret"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when the app secret is missing" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when a required value is only whitespace" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "   "
      ENV["META_APP_SECRET"] = "secret"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when the app id is not numeric" do
      ENV["META_APP_ID"] = "abc def"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"
      ENV["META_APP_SECRET"] = "secret"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is false when the configuration id is not numeric" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "config-1"
      ENV["META_APP_SECRET"] = "secret"

      expect(described_class.embedded_signup_ready?).to be(false)
    end

    it "is true when the app id, configuration id and app secret are all set" do
      ENV["META_APP_ID"] = "1234567890"
      ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"
      ENV["META_APP_SECRET"] = "secret"

      expect(described_class.embedded_signup_ready?).to be(true)
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

  describe "boot check" do
    def boot_app(display_name)
      env = { "RAILS_ENV" => "test", "META_APP_DISPLAY_NAME" => display_name }
      Open3.capture3(env, "bin/rails", "runner", "puts :booted", chdir: Rails.root.to_s)
    end

    it "stops the app from booting when META_APP_DISPLAY_NAME uses a Meta brand word" do
      _stdout, stderr, status = boot_app("Meta Desk")

      expect(status).not_to be_success
      expect(stderr).to include("InvalidDisplayName")
    end

    it "boots cleanly with a valid display name" do
      stdout, _stderr, status = boot_app("Northwind Desk")

      expect(status).to be_success
      expect(stdout).to include("booted")
    end
  end
end
