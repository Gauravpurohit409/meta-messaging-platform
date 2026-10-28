FactoryBot.define do
  factory :template do
    user
    sequence(:name) { |n| "order_ready_#{n}" }
    language { "en_US" }
    category { "UTILITY" }
    status { "draft" }
    body { "Hi {{1}}, your order {{2}} is ready for pickup at the counter." }
    example_values { { "body_1" => "Asha", "body_2" => "NW-1042" } }
  end
end
