source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# Rails 8.0 still passes quirks_mode into JSON.generate. JSON 3 removed that keyword.
gem "json", "~> 2.18"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Tailwind v4. The stylesheet uses `@import "tailwindcss"`.
# bundle install prints a note about pinning "~> 3.3.1"; that pin is for apps
# still on Tailwind v3 and would break this CSS. It is not a build failure.
gem "tailwindcss-rails", "~> 4.0"
# Redis backs Sidekiq and Action Cable so campaign workers can update the desk live.
# Action Cable 8.0 loads the redis gem and rejects 6.x. Sidekiq itself uses redis-client.
gem "redis", "~> 5.4"
gem "sidekiq", "~> 8.0"

# Meta Graph API client.
gem "faraday"

# Sign-in for the desk. bcrypt comes in through Devise.
gem "devise"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "foreman", require: false
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
