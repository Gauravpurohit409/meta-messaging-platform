FactoryBot.define do
  factory :user do
    name { "Asha Menon" }
    company { "Northwind Grocery" }
    sequence(:email) { |n| "person#{n}@marquee.test" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
