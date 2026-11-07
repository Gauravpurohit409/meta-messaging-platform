require "rails_helper"

RSpec.describe Accounts::MailSetup do
  around do |example|
    previous_access = Devise.allow_unconfirmed_access_for
    previous_smtp = ENV["SMTP_ADDRESS"]
    example.run
  ensure
    Devise.allow_unconfirmed_access_for = previous_access
    previous_smtp.nil? ? ENV.delete("SMTP_ADDRESS") : ENV["SMTP_ADDRESS"] = previous_smtp
  end

  it "keeps confirmation required outside production" do
    ENV["SMTP_ADDRESS"] = nil

    expect(described_class.confirmation_required?).to be(true)
  end

  it "lets production sign-ups through until SMTP is configured" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    ENV.delete("SMTP_ADDRESS")

    expect(described_class.confirmation_required?).to be(false)
    described_class.apply!
    expect(Devise.allow_unconfirmed_access_for).to be_nil
  end

  it "keeps confirmation required in production when SMTP is set" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    ENV["SMTP_ADDRESS"] = "smtp.example.com"

    expect(described_class.confirmation_required?).to be(true)
  end
end
