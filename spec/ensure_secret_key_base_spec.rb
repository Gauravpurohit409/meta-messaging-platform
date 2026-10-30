require "rails_helper"
require_relative "../config/ensure_secret_key_base"

RSpec.describe EnsureSecretKeyBase do
  it "keeps a secret that was already set" do
    env = { "SECRET_KEY_BASE" => "a" * 40 }

    described_class.apply!(env, path: "/tmp/marquee-secret-should-not-be-used")

    expect(env["SECRET_KEY_BASE"]).to eq("a" * 40)
  end

  it "replaces a blank secret and reuses it for the next boot" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "secret_key_base")
      first = { "SECRET_KEY_BASE" => "" }
      second = { "SECRET_KEY_BASE" => "   " }

      described_class.apply!(first, path: path)
      described_class.apply!(second, path: path)

      expect(first["SECRET_KEY_BASE"]).to match(/\A[0-9a-f]{128}\z/)
      expect(second["SECRET_KEY_BASE"]).to eq(first["SECRET_KEY_BASE"])
    end
  end
end
