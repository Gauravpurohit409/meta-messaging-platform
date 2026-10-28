require "rails_helper"

RSpec.describe Meta::TemplatePayload do
  it "builds the Graph API components, including samples" do
    template = Template.new(
      name: "order_ready",
      language: "en_US",
      category: "UTILITY",
      header_text: "Order {{1}} update",
      body: "Hi {{1}}, your order {{2}} is ready for pickup.",
      footer_text: "Thank you",
      buttons: [ { "type" => "URL", "text" => "Track", "url" => "https://northwind.example/orders/{{1}}" } ],
      example_values: { "header_1" => "NW-1", "body_1" => "Asha", "body_2" => "NW-1", "url_0" => "NW-1" }
    )

    payload = described_class.build(template)

    expect(payload[:name]).to eq("order_ready")
    expect(payload[:allow_category_change]).to be(true)
    expect(payload[:components].map { |component| component[:type] }).to eq(%w[HEADER BODY FOOTER BUTTONS])
    expect(payload[:components][1][:example][:body_text]).to eq([ [ "Asha", "NW-1" ] ])
    expect(payload[:components].last[:buttons].first[:example]).to eq([ "NW-1" ])
  end
end
