class Rack::Attack
  Rack::Attack.enabled = !Rails.env.test?

  Rack::Attack.cache.store =
    if ENV["REDIS_URL"].present? && !Rails.env.test?
      ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
    else
      ActiveSupport::Cache::MemoryStore.new
    end

  throttle("sign_in/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/users/sign_in"
  end

  throttle("sign_up/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/users"
  end

  throttle("password_reset/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/users/password"
  end

  throttle("embedded_signup/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/settings/embedded_signup"
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [ 429, { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s }, [ "Too many requests. Try again later.\n" ] ]
  end
end
