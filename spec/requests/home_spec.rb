require "rails_helper"

RSpec.describe "Home", type: :request do
  it "explains the desk before sign-in" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Get the template approved")
  end
end
