require "faraday"

class ApplicationJob < ActiveJob::Base
  queue_as :default
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 4
  discard_on ActiveRecord::RecordNotFound
end
