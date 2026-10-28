require "rails_helper"

RSpec.describe Meta::MessagePayload do
  it "places body and link variables where Meta expects them" do
    template = Template.new(
      name: "order_ready",
      language: "en_US",
      body: "Hi {{1}}, order {{2}} is ready.",
      buttons: [
        { "type" => "QUICK_REPLY", "text" => "Thanks" },
        { "type" => "URL", "text" => "Track", "url" => "https://northwind.example/orders/{{1}}" }
      ]
    )

    payload = described_class.build(
      template: template,
      to: "+91 98300 01111",
      parameters: { "body_1" => "Asha", "body_2" => "NW-9", "url_1" => "NW-9" }
    )

    expect(payload[:to]).to eq("919830001111")
    expect(payload[:template][:components][0][:parameters].map { |item| item[:text] }).to eq([ "Asha", "NW-9" ])
    button = payload[:template][:components].last
    expect(button[:index]).to eq("1")
    expect(button[:parameters].first[:text]).to eq("NW-9")
  end
end
