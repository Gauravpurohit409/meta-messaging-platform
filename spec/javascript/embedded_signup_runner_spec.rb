require "rails_helper"
require "open3"

RSpec.describe "Embedded Signup browser behavior" do
  it "runs the controller against finish, cancel, and a foreign origin" do
    output, status = Open3.capture2e(
      "node",
      "--import", Rails.root.join("spec/javascript/register-hooks.mjs").to_s,
      "--test", Rails.root.join("spec/javascript/embedded_signup_controller.test.mjs").to_s
    )

    expect(status).to be_success, output
  end
end
