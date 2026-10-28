require "rails_helper"

RSpec.describe Campaigns::AudienceParser do
  it "reads phone lines and a csv with variable columns" do
    text = <<~CSV
      phone,1,body_2
      +91 98300 01111,Asha,NW-1
      919830002222,Rahul,NW-2
      123,Nope,NW-3
    CSV

    result = described_class.call(text: text)

    expect(result.errors.join).to include("123")
    expect(result.recipients.map(&:phone)).to eq(%w[919830001111 919830002222])
    expect(result.recipients.first.parameters).to eq("body_1" => "Asha", "body_2" => "NW-1")
  end

  it "flags duplicate numbers" do
    result = described_class.call(text: "919830001111\n919830001111")
    expect(result.errors.join).to include("more than once")
    expect(result.recipients.size).to eq(1)
  end
end
