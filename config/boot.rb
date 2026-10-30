ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

if ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
  require_relative "ensure_secret_key_base"
  EnsureSecretKeyBase.apply!
end
