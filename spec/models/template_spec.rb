require "rails_helper"

RSpec.describe Template, type: :model do
  it "rejects a body that starts with a variable or skips a number" do
    template = build(:template, body: "{{1}}, your order is ready for pickup today.")
    expect(template).not_to be_valid
    expect(template.errors[:body].join).to include("cannot start or end")

    template.body = "Hi {{1}}, your order {{3}} is ready for pickup."
    expect(template).not_to be_valid
    expect(template.errors[:body].join).to include("sequential")
  end

  it "lists only approved templates for a campaign" do
    user = create(:user)
    approved = create(:template, user: user, status: "approved")
    create(:template, user: user, status: "draft")

    expect(user.templates.approved).to contain_exactly(approved)
  end

  it "requires samples before submission" do
    template = create(:template, example_values: {})
    expect(template.valid?(:submit)).to be(false)
    expect(template.errors.full_messages.join).to include("Body {{1}}")
  end

  it "rejects variables in the footer and a second header variable" do
    template = build(:template, footer_text: "Order {{1}}", header_text: "Hi {{1}} and {{2}} today")
    expect(template).not_to be_valid
    expect(template.errors[:footer_text]).to be_present
    expect(template.errors[:header_text]).to be_present
  end
end
