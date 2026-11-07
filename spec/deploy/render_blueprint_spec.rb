require "rails_helper"
require "yaml"

RSpec.describe "Render blueprint" do
  let(:blueprint) { YAML.safe_load_file(Rails.root.join("render.yaml")) }

  it "uses no free plans" do
    plans = [ blueprint.fetch("databases"), blueprint.fetch("services") ].flatten.map { |entry| entry["plan"] }
    expect(plans).not_to include("free")
  end

  it "purges retained data every day" do
    cron = blueprint.fetch("services").find { |entry| entry["type"] == "cron" && entry["name"] == "meta-messaging-retention" }
    expect(cron["startCommand"]).to eq("bundle exec rails retention:purge")
  end
end