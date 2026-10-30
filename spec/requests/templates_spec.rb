require "rails_helper"

RSpec.describe "Templates", type: :request do
  include Devise::Test::IntegrationHelpers

  it "offers utility, marketing, and authentication on the draft form" do
    sign_in create(:user)

    get new_template_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Template type")
    expect(response.body).to include("Meta accepts only utility, marketing, and authentication.")
    expect(response.body).to include('value="UTILITY"')
    expect(response.body).to include('value="MARKETING"')
    expect(response.body).to include('value="AUTHENTICATION"')
  end

  it "saves an authentication template from the type option" do
    user = create(:user)
    sign_in user

    post templates_path, params: {
      template: {
        name: "login_code",
        language: "en_US",
        category: "AUTHENTICATION",
        body: "Your login code is {{1}}. It expires shortly.",
        example_values: { "body_1" => "482913" }
      }
    }

    template = user.templates.find_by!(name: "login_code")
    expect(template.category).to eq("AUTHENTICATION")
    expect(response).to redirect_to(template)
  end

  it "filters the desk by template type" do
    user = create(:user)
    create(:template, user: user, name: "order_ready", category: "UTILITY")
    create(:template, user: user, name: "festive_hamper", category: "MARKETING")
    sign_in user

    get templates_path(category: "MARKETING")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("festive_hamper")
    expect(response.body).not_to include("order_ready")
  end
end
