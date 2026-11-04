require "rails_helper"

RSpec.describe "App name", type: :request do
  around do |example|
    saved = ENV["META_APP_DISPLAY_NAME"]
    ENV.delete("META_APP_DISPLAY_NAME")
    example.run
  ensure
    saved.nil? ? ENV.delete("META_APP_DISPLAY_NAME") : ENV["META_APP_DISPLAY_NAME"] = saved
  end

  it "uses Marquee on the home page by default" do
    get "/"

    expect(response.body).to include("<title>Marquee — WhatsApp templates and campaigns</title>")
    expect(response.body).to include(">Marquee</p>")
  end

  it "uses META_APP_DISPLAY_NAME on the home page title and header" do
    ENV["META_APP_DISPLAY_NAME"] = "Northwind Desk"

    get "/"

    expect(response.body).to include("<title>Northwind Desk — WhatsApp templates and campaigns</title>")
    expect(response.body).to include(">Northwind Desk</p>")
    expect(response.body).not_to include(">Marquee</p>")
  end

  it "uses META_APP_DISPLAY_NAME on the sign-in page" do
    ENV["META_APP_DISPLAY_NAME"] = "Northwind Desk"

    get new_user_session_path

    expect(response.body).to include("<title>Sign in — Northwind Desk</title>")
  end
end
