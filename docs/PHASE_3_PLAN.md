# Phase 3 plan: compliance, consent, and hardening

This plan is written so a smaller model can apply it step by step. Follow it literally. Where it gives a file path, column, message, or route, use exactly that. If something in the repo contradicts the plan, stop and report it instead of guessing.

Phase 3 is one branch and one pull request, built in three commits (3a, 3b, 3c). The owner will test all of Phase 3 together at the end, so every step below has its own specs and the whole suite has to be green at each commit.

## 0. Ground rules

1. Base branch: the branch that contains Phase 2 and 2b (`cursor/embedded-signup-sdk-d8e3` until #8 and #9 merge, then `main`). Branch name: `cursor/phase-3-compliance-d8e3`.
2. Tests first. Commit 1 is failing specs only (all of section 7). Stop and wait for the owner's approval. Only then implement.
3. Do not edit any Phase 2 or 2b spec to make it pass. Only edit specs this plan names (section 8 lists them).
4. Do not add features that are not in this plan (no reply composer, no email digests, no admin screens).
5. Environment for every command:
   ```bash
   export BUNDLE_PATH=$HOME/.gems-marquee RAILS_ENV=test
   sudo service postgresql start && sudo service redis-server start
   ```
6. After every step run `bundle exec rspec` and `bundle exec rubocop <files you touched>`. Fix what you broke before moving on.
7. Rails facts that bit earlier phases. Do not relearn them:
   - Test env uses `show_exceptions = :rescuable`, so a missing route is HTTP 404, not an exception.
   - CSRF protection is off in test. Specs that need it turn `ActionController::Base.allow_forgery_protection` on and restore it.
   - `valid?` and `update!` clear `errors`. Add errors after the last save or validation.
   - `Faraday.new` is stubbed in specs. Never call Meta from a controller or job path a spec does not stub.
   - `PhoneNumbers.normalize` returns digits only (no `+`). Use it for every phone number you store or compare.
   - `config/environments/test.rb` uses `:null_store` for cache. Anything that needs a cache (rate limits) must set its own store.
8. Commit messages: one short imperative subject, then a sentence of why. Push once at the end of each commit group, then open or update the PR with the pull request tool (never `gh`).

## 1. Decisions already made (do not reopen)

| Topic | Decision |
| --- | --- |
| Consent applies to | MARKETING templates only. UTILITY and AUTHENTICATION still send to opted-out numbers. |
| Opt-out words | Exact match after trimming, lowercasing, and removing punctuation: `stop`, `stop all`, `unsubscribe`, `cancel`, `end`, `quit`, `opt out`, `optout`. |
| Opt-in words | `start`, `unstop`, `subscribe`. Nothing else re-activates a number. |
| Re-opting in | Uploading the number again in a campaign never un-revokes it. Only an inbound opt-in word does. |
| Confirmation reply to STOP | Not sent in this phase. |
| Inbox | Read-only list of the last 100 inbound messages. No replying. |
| Meta data deletion callback | Records the request, returns a status URL and confirmation code. Marquee stores no Facebook profile data, so the status page says so and points to account deletion. |
| Account deletion | A signed-in user can delete their account from the Account page. This removes templates, campaigns, recipients, consents, inbound messages, and disconnects Meta if live. |
| Retention | Webhook events 30 days, recipients of finished campaigns 180 days. Both configurable by env. Run daily by a Render cron service. |
| Hosting | Move off Render free plans for web, Postgres, and key-value so webhooks and sends never stop. This costs money, so the owner confirms before this step ships. |

## 2. Data model changes

Create these migrations in this order. Timestamps are fixed so they sort after Phase 2.

### 2.1 `db/migrate/20261107100000_create_consents.rb`

```ruby
class CreateConsents < ActiveRecord::Migration[8.0]
  def change
    create_table :consents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.string :source, null: false
      t.text :wording, null: false
      t.datetime :consented_at, null: false
      t.datetime :revoked_at
      t.string :revoked_reason
      t.timestamps
    end
    add_index :consents, %i[user_id phone_number], unique: true
  end
end
```

### 2.2 `db/migrate/20261107100100_create_inbound_messages.rb`

```ruby
class CreateInboundMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :inbound_messages do |t|
      t.references :whatsapp_account, null: false, foreign_key: true
      t.string :wa_message_id, null: false
      t.string :from_number, null: false
      t.string :message_type, null: false, default: "text"
      t.text :body
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :inbound_messages, :wa_message_id, unique: true
    add_index :inbound_messages, %i[whatsapp_account_id received_at]
  end
end
```

### 2.3 `db/migrate/20261107100200_create_data_deletion_requests.rb`

```ruby
class CreateDataDeletionRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :data_deletion_requests do |t|
      t.string :confirmation_code, null: false
      t.string :meta_user_id
      t.string :status, null: false, default: "completed"
      t.timestamps
    end
    add_index :data_deletion_requests, :confirmation_code, unique: true
  end
end
```

### 2.4 `db/migrate/20261107100300_add_devise_confirmable_and_lockable_to_users.rb`

```ruby
class AddDeviseConfirmableAndLockableToUsers < ActiveRecord::Migration[8.0]
  def up
    change_table :users, bulk: true do |t|
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email
      t.integer :failed_attempts, default: 0, null: false
      t.string :unlock_token
      t.datetime :locked_at
    end
    add_index :users, :confirmation_token, unique: true
    add_index :users, :unlock_token, unique: true
    execute "UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL"
  end

  def down
    remove_index :users, :unlock_token
    remove_index :users, :confirmation_token
    change_table :users, bulk: true do |t|
      t.remove :confirmation_token, :confirmed_at, :confirmation_sent_at, :unconfirmed_email,
               :failed_attempts, :unlock_token, :locked_at
    end
  end
end
```

The `UPDATE` keeps everyone who already has an account able to sign in.

After writing the migrations run `bin/rails db:migrate` (test env) and commit the regenerated `db/schema.rb`.

### 2.5 Models

`app/models/consent.rb`

```ruby
class Consent < ApplicationRecord
  SOURCES = %w[campaign_upload manual_entry inbound_message].freeze

  belongs_to :user

  before_validation { self.phone_number = PhoneNumbers.normalize(phone_number) }

  validates :phone_number, presence: true, uniqueness: { scope: :user_id }
  validates :source, inclusion: { in: SOURCES }
  validates :wording, :consented_at, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  # Records an opt-in. Never re-activates a number that has opted out.
  def self.record!(user:, phone_number:, source:, wording:)
    number = PhoneNumbers.normalize(phone_number)
    existing = find_by(user: user, phone_number: number)
    return existing if existing

    create!(user: user, phone_number: number, source: source, wording: wording, consented_at: Time.current)
  end

  def self.revoke!(user:, phone_number:, reason:)
    number = PhoneNumbers.normalize(phone_number)
    record = find_or_initialize_by(user: user, phone_number: number)
    record.source ||= "inbound_message"
    record.wording ||= "Opted out by message"
    record.consented_at ||= Time.current
    record.revoked_at ||= Time.current
    record.revoked_reason = reason if record.revoked_reason.blank?
    record.save!
    record
  end

  def self.restore!(user:, phone_number:)
    record = find_by(user: user, phone_number: PhoneNumbers.normalize(phone_number))
    record&.update!(revoked_at: nil, revoked_reason: nil)
    record
  end
end
```

`app/models/inbound_message.rb`

```ruby
class InboundMessage < ApplicationRecord
  belongs_to :whatsapp_account

  validates :wa_message_id, :from_number, :received_at, presence: true
  validates :wa_message_id, uniqueness: true
end
```

`app/models/data_deletion_request.rb`

```ruby
class DataDeletionRequest < ApplicationRecord
  before_validation { self.confirmation_code ||= SecureRandom.hex(8) }

  validates :confirmation_code, presence: true, uniqueness: true
end
```

Edit `app/models/user.rb`:
- Add `:confirmable, :lockable` to the `devise` call.
- Add `has_many :consents, dependent: :destroy`.
- Add `has_many :inbound_messages, through: :whatsapp_account`.
- Add `before_destroy :disconnect_from_meta` (private method below). It must run before `has_one :whatsapp_account, dependent: :destroy`, so declare it above the associations.

```ruby
def disconnect_from_meta
  account = whatsapp_account
  return if account.nil? || account.demo_mode? || account.access_token.blank?

  Meta::EmbeddedSignup.disconnect(account)
rescue StandardError => error
  Rails.logger.warn("Meta disconnect skipped during account deletion: #{error.class}")
end
```

Edit `app/models/whatsapp_account.rb`: add `has_many :inbound_messages, dependent: :destroy`.

## 3. Phase 3a: legal pages and data

### 3a.1 Public pages
- Routes: `get "privacy", to: "pages#privacy"`, `get "terms", to: "pages#terms"`.
- `PagesController` already skips authentication. Add empty actions `privacy` and `terms`.
- Views `app/views/pages/privacy.html.erb` and `terms.html.erb`. Use the same layout wrapper as `pages/home.html.erb`. Set `content_for :title`.
- Privacy page must state, in plain sentences: what is stored (name, email, company, WhatsApp phone numbers and message content customers upload, delivery status), that messages go to Meta's WhatsApp Business Platform, the retention periods (read from `Retention.webhook_days` and `Retention.recipient_days`, section 3a.3), how to delete data (Account page, or email `ENV["SUPPORT_EMAIL"]`), and the data deletion status URL pattern.
- Terms page must state: customers may only message people who opted in, the marketing opt-out rule, WhatsApp Business policy compliance, and that accounts that breach Meta's policies can be suspended.
- Add `app_support_email` to `app/helpers/application_helper.rb`: `ENV["SUPPORT_EMAIL"].presence || "support@example.com"`.
- Footer links "Privacy" and "Terms" on: `pages/home.html.erb` footer, `shared/_auth_frame.html.erb`, and `layouts/application.html.erb` (small links under the sidebar user block). Use `link_to "Privacy", privacy_path` and `link_to "Terms", terms_path`.

### 3a.2 Data deletion callback and status page
- Routes inside `namespace :webhooks`: `post "data_deletion", to: "data_deletion#create"`. Outside it: `get "data_deletion/:code", to: "data_deletion#show", as: :data_deletion_status` (controller `DataDeletionController`, public).
- `Webhooks::DataDeletionController#create`:
  - `skip_before_action :authenticate_user!` and `skip_before_action :verify_authenticity_token`.
  - Read `params[:signed_request]`. Parse it with the method below. If it returns `nil`, `head :bad_request`.
  - Otherwise create `DataDeletionRequest.create!(meta_user_id: payload["user_id"])` and render JSON `{ url: data_deletion_status_url(code: request.confirmation_code), confirmation_code: request.confirmation_code }`.

```ruby
def parse_signed_request(raw)
  encoded_signature, encoded_payload = raw.to_s.split(".", 2)
  secret = ENV["META_APP_SECRET"].to_s
  return nil if encoded_signature.blank? || encoded_payload.blank? || secret.blank?

  signature = Base64.urlsafe_decode64(encoded_signature)
  expected = OpenSSL::HMAC.digest("SHA256", secret, encoded_payload)
  return nil unless signature.bytesize == expected.bytesize &&
                    ActiveSupport::SecurityUtils.secure_compare(signature, expected)

  JSON.parse(Base64.urlsafe_decode64(encoded_payload))
rescue ArgumentError, JSON::ParserError
  nil
end
```

- `DataDeletionController#show` (public, route above): find by `confirmation_code`; unknown code is HTTP 404. Page text: "Request <code> is complete. Marquee does not store a Facebook profile for you. To delete the business data held in your Marquee desk, delete your account from Account settings or email <support email>."

### 3a.3 Account deletion and retention
- `app/views/devise/registrations/edit.html.erb` currently has no delete control. Add a section at the bottom with `button_to "Delete my account", registration_path(resource_name), method: :delete, data: { turbo_confirm: "Delete your account and all of its data? This cannot be undone." }`. Devise's built-in `destroy` action handles the request; `User#before_destroy` disconnects Meta and `dependent: :destroy` removes the rest. Sign-out and redirect to root are Devise's default.
- `app/services/retention.rb`:

```ruby
module Retention
  module_function

  def webhook_days
    positive_integer("RETENTION_WEBHOOK_DAYS", 30)
  end

  def recipient_days
    positive_integer("RETENTION_RECIPIENT_DAYS", 180)
  end

  def purge!(now: Time.current)
    webhooks = WebhookEvent.where("created_at < ?", now - webhook_days.days).delete_all
    stale = Campaign.where(status: %w[completed failed]).where("completed_at < ?", now - recipient_days.days)
    recipients = CampaignRecipient.where(campaign_id: stale.select(:id)).delete_all
    { webhook_events: webhooks, campaign_recipients: recipients }
  end

  def positive_integer(key, default)
    value = ENV[key].to_i
    value.positive? ? value : default
  end
end
```

- `lib/tasks/retention.rake`: `namespace :retention do desc "Delete data past its retention period"; task purge: :environment do puts Retention.purge!.inspect end end`.
- `render.yaml`: add a cron service (copy the `envVars` block from the existing worker service):

```yaml
  - type: cron
    name: meta-messaging-retention
    runtime: ruby
    plan: starter
    region: singapore
    schedule: "0 21 * * *"
    buildCommand: bundle install
    startCommand: bundle exec rails retention:purge
    envVars: # same list as meta-messaging-worker
```

## 4. Phase 3b: consent, suppression, inbox

### 4b.1 Capture consent when a campaign is created
- In `app/views/campaigns/new.html.erb`, inside the Audience card add:
  - a required checkbox `consent_confirmed` labelled "Everyone on this list agreed to receive WhatsApp messages from us"
  - a text input `consent_source_note` labelled "Where did they agree? (for example: checkout form, in store sign-up)"
- In `CampaignsController#create`, before saving: if `params[:consent_confirmed] != "1"` or `params[:consent_source_note].to_s.strip.blank?`, add base errors "Confirm that everyone on the list opted in" or "Say where the opt-in was collected" and render `:new` with 422 (the same path used for the other audience errors). This applies to every category, because the checkbox is part of the form.
- After the recipients are created (inside the same transaction), for each parsed row call:

```ruby
Consent.record!(
  user: current_user,
  phone_number: row.phone,
  source: "campaign_upload",
  wording: params[:consent_source_note].to_s.strip.truncate(500)
)
```

### 4b.2 Block marketing launches without consent
In `Campaigns::Launcher#call`, after the "Add at least one recipient" check and before `missing_parameters`, add:

```ruby
if @campaign.template.category == "MARKETING"
  missing = missing_consent_numbers
  if missing.any?
    @campaign.errors.add(:base, "#{missing.size} recipients have no opt-in record: #{missing.first(3).join(', ')}")
    next
  end
end
```

with

```ruby
def missing_consent_numbers
  numbers = @campaign.recipients.pluck(:phone_number)
  consented = Consent.where(user_id: @campaign.user_id, phone_number: numbers).pluck(:phone_number)
  numbers - consented
end
```

(A revoked number has a consent row, so it passes launch and is skipped at send time. That is intentional: the campaign shows the failure per recipient.)

### 4b.3 Skip opted-out numbers at send time
In `SendMessageJob#perform`, after the restricted-account check and before `Meta::Client.new`:

```ruby
if campaign.template.category == "MARKETING" &&
   Consent.where(user_id: campaign.user_id, phone_number: recipient.phone_number).where.not(revoked_at: nil).exists?
  recipient.mark_failed!(code: "opted_out", message: "This person opted out of marketing messages")
  return
end
```

### 4b.4 Handle inbound messages
- New service `app/services/inbox/apply_inbound_messages.rb`. `ProcessWebhookJob` calls it from the `"messages"` branch in addition to `Campaigns::ApplyMessageStatus.call(event.payload)`.
- Payload shape stored by `Webhooks::MetaController`: `{ "waba_id" => entry_id, "value" => change_value }`. Inbound messages are at `value["messages"]` (array of hashes with `id`, `from`, `timestamp` (unix seconds as a string), `type`, and `text.body` for text, `button.text` and `button.payload` for quick replies). The receiving number is `value.dig("metadata", "phone_number_id")`.

```ruby
module Inbox
  class ApplyInboundMessages
    STOP_WORDS = ["stop", "stop all", "unsubscribe", "cancel", "end", "quit", "opt out", "optout"].freeze
    START_WORDS = %w[start unstop subscribe].freeze

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @value = payload["value"].is_a?(Hash) ? payload["value"] : {}
    end

    def call
      account = WhatsappAccount.find_by(phone_number_id: @value.dig("metadata", "phone_number_id").to_s)
      return if account.nil?

      Array(@value["messages"]).each { |message| apply(account, message) }
    end

    private

    def apply(account, message)
      id = message["id"].to_s
      return if id.blank? || InboundMessage.exists?(wa_message_id: id)

      from = PhoneNumbers.normalize(message["from"])
      text = text_of(message)
      InboundMessage.create!(
        whatsapp_account: account,
        wa_message_id: id,
        from_number: from,
        message_type: message["type"].presence || "text",
        body: text,
        received_at: Time.zone.at(message["timestamp"].to_i)
      )

      word = text.to_s.downcase.gsub(/[[:punct:]]/, "").squeeze(" ").strip
      if STOP_WORDS.include?(word)
        Consent.revoke!(user: account.user, phone_number: from, reason: word)
      elsif START_WORDS.include?(word)
        Consent.restore!(user: account.user, phone_number: from)
      end
    end

    def text_of(message)
      message.dig("text", "body").presence || message.dig("button", "text").presence || message.dig("button", "payload")
    end
  end
end
```

Edge cases the specs below pin down: a duplicate delivery of the same message id is ignored; an unknown phone number id does nothing and does not raise; the sentence "please do not stop" is not an opt-out; punctuation and case ("Stop!", " STOP ") still match; a status-only payload with no `messages` does nothing.

### 4b.5 Inbox page
- Route: `resources :inbox, only: :index, controller: "inbox"` is awkward; use `get "inbox", to: "inbox#index", as: :inbox`.
- `InboxController#index`: `@messages = current_user.whatsapp_account.inbound_messages.order(received_at: :desc).limit(100)`.
- View `app/views/inbox/index.html.erb`: heading "Inbox", a list showing `from_number`, `body`, and the time with `stamp(message.received_at)` (existing helper). Empty state sentence: "No replies yet." Use `content_for :heading`.
- Add a "Inbox" link to the sidebar nav in `layouts/application.html.erb` next to "Connection" using `nav_class(inbox_path)`.

### 4b.6 Require an opt-out line on marketing templates
- In `app/models/template.rb` add `validate :marketing_has_opt_out, on: :submit`:

```ruby
OPT_OUT_PATTERN = /\b(stop|opt[\s-]?out|unsubscribe)\b/i

def marketing_has_opt_out
  return unless category == "MARKETING"
  return if footer_text.to_s.match?(OPT_OUT_PATTERN)
  return if Array(buttons).any? { |b| b["type"] == "QUICK_REPLY" && b["text"].to_s.match?(OPT_OUT_PATTERN) }

  errors.add(:base, "Marketing templates need an opt-out line, for example the footer “Reply STOP to opt out”")
end
```

- In `app/views/templates/_form.html.erb`, under the footer field add a hint: "Marketing templates need a footer or quick-reply button that tells people how to opt out, for example “Reply STOP to opt out”."
- Seeds: any seeded MARKETING template must get `footer_text: "Reply STOP to opt out"`.

## 5. Phase 3c: hardening

### 5c.1 Rate limits (Rack::Attack)
- Add `gem "rack-attack"` to the Gemfile, run `bundle install`.
- `config/initializers/rack_attack.rb`:

```ruby
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
```

- `config/application.rb`: add `config.middleware.use Rack::Attack` inside the application class. Do not throttle `/webhooks/meta` or `/up`.
- Why disabled in test: the suite signs in far more than 10 times a minute. The rate-limit spec turns it on and resets the store.

### 5c.2 Email confirmation and lockout
- `config/initializers/devise.rb`: set (uncomment and edit, do not duplicate):
  - `config.allow_unconfirmed_access_for = 0.days`
  - `config.reconfirmable = true` (already set)
  - `config.lock_strategy = :failed_attempts`
  - `config.unlock_strategy = :both`
  - `config.maximum_attempts = 5`
  - `config.unlock_in = 1.hour`
  - `config.last_attempt_warning = true`
- `spec/factories/users.rb`: add `confirmed_at { Time.current }` so every existing spec still signs in. Add a `:unconfirmed` trait with `confirmed_at { nil }`.
- `db/seeds.rb`: after building the demo user set `demo.confirmed_at ||= Time.current` before `save!`, and call `demo.update!(confirmed_at: Time.current) if demo.confirmed_at.nil?` for an existing demo user.
- Production mail in `config/environments/production.rb`, replacing the commented SMTP block:

```ruby
if ENV["SMTP_ADDRESS"].present?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", "587").to_i,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
end
```

- `.env.example` and README: add `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SUPPORT_EMAIL`, `RETENTION_WEBHOOK_DAYS`, `RETENTION_RECIPIENT_DAYS`. Add them to the `render.yaml` web service as `sync: false` entries (except retention, which get default values).
- The Devise confirmation and unlock views already exist under `app/views/devise/`; do not rewrite them.
- Existing specs that sign up a user and expect to be signed in must be updated (see section 8).

### 5c.3 Always-on hosting (ask the owner before shipping)
In `render.yaml`:
- web service `plan: free` becomes `plan: starter`.
- Postgres `plan: free` becomes a paid plan. Check the current plan names in Render's docs before editing; at the time of writing the smallest paid database is `basic-256mb`.
- key-value `plan: free` becomes `plan: starter` (free key-value drops data on restart, which loses queued sends).
- Update the README Render table and the comment at the top of `render.yaml`.
The spec only checks that no service in `render.yaml` uses `plan: free`.

## 6. Environment variables added

`SUPPORT_EMAIL`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `RETENTION_WEBHOOK_DAYS`, `RETENTION_RECIPIENT_DAYS`. Document all in `.env.example` and the README.

## 7. Specs to write first (commit 1, all red)

Create each file. Names below are `describe`/`it` text; assert exactly what is listed.

### 7.1 `spec/models/consent_spec.rb`
- `record!` creates a row with normalized digits (`"+91 98300 01111"` stored as `919830001111`), source, wording, `consented_at`.
- `record!` twice for the same user and number returns the same row and does not create a second.
- `record!` does not re-activate a revoked row (`revoked_at` stays set).
- `revoke!` for a number with no row creates a row with `revoked_at` set and the reason.
- `revoke!` keeps the first `revoked_at` if called again.
- `restore!` clears `revoked_at` and `revoked_reason`; returns nil when no row exists.
- Two users can hold a consent for the same number.
- Invalid `source` is rejected.

### 7.2 `spec/services/inbox/apply_inbound_messages_spec.rb`
Build payloads as `{ "waba_id" => "111", "value" => { "metadata" => { "phone_number_id" => "222" }, "messages" => [ { "id" => "wamid.1", "from" => "919830001111", "timestamp" => "1762500000", "type" => "text", "text" => { "body" => "Hello" } } ] } }` with a live desk whose `phone_number_id` is `"222"`.
- stores one `InboundMessage` with from, body, type, and `received_at` equal to `Time.zone.at(1762500000)`.
- `"STOP"`, `" Stop! "`, `"opt out"`, `"Unsubscribe"` each revoke consent for the desk owner and that number.
- `"please do not stop"` does not revoke.
- `"START"` after a revoke restores the consent.
- quick-reply button `{ "type" => "button", "button" => { "text" => "Stop", "payload" => "STOP" } }` revokes.
- the same message id delivered twice creates one row and revokes once.
- unknown `phone_number_id` creates nothing and does not raise.
- payload with only `statuses` and no `messages` creates nothing.
- a revoke for desk A's user does not touch desk B's user for the same number.

### 7.3 `spec/jobs/process_webhook_job_spec.rb` (new)
- a `messages` webhook event with an inbound STOP revokes consent and marks the event processed.
- a `messages` event with statuses still updates recipient status (call through to `Campaigns::ApplyMessageStatus`).

### 7.4 `spec/jobs/send_message_job_spec.rb` (append, do not change existing examples)
- opted-out number on a MARKETING campaign: recipient failed, error_code `opted_out`, message matches `/opted out/i`, `Meta::Client` never instantiated.
- the same opted-out number on a UTILITY campaign is sent normally.
- an active consent on a MARKETING campaign is sent normally.

### 7.5 `spec/services/campaigns/launcher_spec.rb` (append to the existing file in `spec/services/campaigns/`)
- MARKETING campaign with a recipient that has no consent row: `call` returns false, error matches `/no opt-in record/`, campaign stays draft.
- MARKETING campaign where every recipient has a consent row (even revoked) launches.
- UTILITY campaign with no consent rows launches.

### 7.6 `spec/requests/campaign_consent_spec.rb`
- creating a campaign without `consent_confirmed` returns 422, error includes "Confirm that everyone on the list opted in", nothing saved.
- creating a campaign with the box ticked but a blank note returns 422, error includes "Say where the opt-in was collected".
- a valid create stores one `Consent` per recipient with source `campaign_upload` and wording equal to the note.
- an existing revoked consent stays revoked after the number is uploaded again.

### 7.7 `spec/models/template_spec.rb` and `spec/requests/templates_spec.rb`
Add (do not alter existing examples except as section 8 says):
- MARKETING template with footer "Reply STOP to opt out" is valid on `:submit`.
- MARKETING template with a QUICK_REPLY button "Stop" is valid on `:submit`.
- MARKETING template with neither is invalid on `:submit` with the error text from 4b.6.
- UTILITY template with neither is valid on `:submit`.
- the footer hint text appears on the new template form.

### 7.8 `spec/requests/inbox_spec.rb`
- signed out: redirected to sign-in.
- shows only the signed-in user's inbound messages (create one for another user and assert it is absent).
- shows at most 100 messages, newest first.
- empty state says "No replies yet."
- the sidebar contains a link to `/inbox`.

### 7.9 `spec/requests/legal_pages_spec.rb`
- `/privacy` and `/terms` return 200 without signing in.
- privacy page includes the retention days (default 30 and 180), the support email, and the words "WhatsApp".
- home page, sign-in page, and the signed-in layout all link to `/privacy` and `/terms`.

### 7.10 `spec/requests/data_deletion_spec.rb`
Build `signed_request` with `ENV["META_APP_SECRET"] = "app-secret"`: `payload = Base64.urlsafe_encode64({ user_id: "42", algorithm: "HMAC-SHA256" }.to_json, padding: false)`, `signature = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", "app-secret", payload), padding: false)`, `"#{signature}.#{payload}"`.
- valid request returns 200 JSON with `url` and `confirmation_code`, and creates one `DataDeletionRequest` with `meta_user_id` "42".
- bad signature returns 400 and creates nothing.
- missing `signed_request` returns 400.
- blank `META_APP_SECRET` returns 400.
- malformed (no dot, bad base64, non-JSON payload) returns 400 and does not raise.
- the status URL returns 200 and mentions the code and "does not store a Facebook profile"; an unknown code returns 404.
- forgery protection on: POST without a token still works (the endpoint is exempt).

### 7.11 `spec/requests/account_deletion_spec.rb`
- `DELETE /users` for a signed-in user removes the user, templates, campaigns, recipients, consents, and the desk, and redirects to root.
- a live desk triggers `Meta::EmbeddedSignup.disconnect` once (stub with `allow(...).to receive(:disconnect).and_return(true)`); the account is still deleted if that stub raises.
- a demo desk never calls `disconnect`.
- another user's data is untouched.
- the Account page contains "Delete my account".

### 7.12 `spec/services/retention_spec.rb`
- webhook events older than 30 days are deleted, newer ones kept.
- recipients of completed or failed campaigns older than 180 days are deleted; campaign rows and counters stay.
- recipients of running or draft campaigns are never deleted.
- `RETENTION_WEBHOOK_DAYS=7` changes the cut-off; `0`, negative, and non-numeric values fall back to the default.
- `purge!` returns counts.
- the rake task `retention:purge` runs without raising (`Rails.application.load_tasks` then `Rake::Task["retention:purge"].invoke`).

### 7.13 `spec/requests/rate_limit_spec.rb`
Set up with `around { Rack::Attack.enabled = true; Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new; example.run; Rack::Attack.enabled = false }`.
- the 11th `POST /users/sign_in` from one IP within a minute returns 429 with a `Retry-After` header; the first 10 do not.
- the 6th `POST /users` in an hour returns 429.
- the 6th `POST /users/password` in an hour returns 429.
- the 11th `POST /settings/embedded_signup` returns 429.
- `/webhooks/meta` is never throttled (30 GET requests all return 403, not 429).
- a different IP (`headers: { "REMOTE_ADDR" => "10.0.0.2" }`) is not affected.

### 7.14 `spec/requests/registration_confirmation_spec.rb`
- sign-up creates an unconfirmed user, sends one confirmation email to that address (`ActionMailer::Base.deliveries`), and does not sign the user in (GET `/dashboard` redirects to sign-in).
- following the link in the email confirms the user and allows sign-in.
- an unconfirmed user cannot sign in and sees the "confirm your email" message.
- 5 failed sign-ins lock the account; the 6th attempt with the right password still fails and an unlock email is sent.
- an unlock link unlocks the account.
- existing users with `confirmed_at` set sign in normally.

### 7.15 `spec/deploy/render_blueprint_spec.rb`
- `render.yaml` parses as YAML; no service or database has `plan: free`.
- a `cron` service named `meta-messaging-retention` exists with start command `bundle exec rails retention:purge`.

### 7.16 `spec/models/user_spec.rb` (append)
- user is `confirmable` and `lockable` (`User.devise_modules` includes both).
- destroying a user removes its consents.

## 8. Existing specs that must change (only these)

Search with `rg -n "sign_up|post user_registration|users_path|MARKETING|create\\(:template, .*category" spec` and update only what fails for the reason below.
- `spec/factories/users.rb`: add `confirmed_at` (section 5c.2).
- Any existing spec that creates a MARKETING template and calls `submit` or the submit endpoint: add `footer_text: "Reply STOP to opt out"` to that template.
- Any existing campaign creation request spec: add `consent_confirmed: "1"` and `consent_source_note: "Checkout form"` to its params.
- `spec/models/template_spec.rb` line using `%w[MARKETING AUTHENTICATION].each`: only touch it if it fails, and then only by adding the footer for MARKETING.
- Any spec that expects sign-up to sign the user in: change it to expect the confirmation flow.
Report every spec you edited in the pull request description.

## 9. Implementation order (commit 2 onward, after approval)

1. Migrations and models (section 2). Run migrations, regenerate `db/schema.rb`. Specs 7.1, 7.16 go green.
2. Inbox service, job wiring, send-time skip, launch check, template validation (4b.3, 4b.4, 4b.6, 4b.2). Specs 7.2 to 7.5, 7.7 go green.
3. Campaign consent form and controller, inbox page (4b.1, 4b.5). Specs 7.6, 7.8 go green.
4. Legal pages, deletion callback, account deletion, retention (section 3). Specs 7.9 to 7.12 go green.
5. Rate limits (5c.1). Spec 7.13 goes green.
6. Confirmable and lockable, mail config, seeds (5c.2). Spec 7.14 goes green. Update the specs listed in section 8.
7. Render blueprint (5c.3). Spec 7.15 goes green. Confirm with the owner first.
8. README and `.env.example` updates (section 6).
9. Full `bundle exec rspec`, `bundle exec rubocop` on touched files, `bundle exec brakeman -q` (report new warnings, do not suppress them).

Commit after steps 1 to 3 (3b), after step 4 (3a), and after steps 5 to 8 (3c). Push once at the end.

## 10. Combined acceptance run (for the owner)

Run these on a fresh database with seeds, in one pass:
1. Sign up a new account. Confirm the email arrives, the account cannot sign in until confirmed, then sign in.
2. Enter a wrong password five times. Confirm the lockout email and unlock link work.
3. Create a MARKETING template without an opt-out line and try to submit it. Confirm the error. Add "Reply STOP to opt out" and submit.
4. Create a campaign without ticking the opt-in box. Confirm it is refused. Tick it, add a source note, save, launch.
5. Send a webhook `messages` payload with `"STOP"` from one recipient. Confirm the Inbox shows it, then launch another marketing campaign to the same number and confirm it fails with "opted out".
6. Send `"START"` from the same number and confirm the next marketing send goes through.
7. Visit `/privacy`, `/terms`, and POST a signed data deletion request. Confirm the status page.
8. Delete the account from the Account page. Confirm everything is gone and a live desk was disconnected from Meta.
9. Run `bundle exec rails retention:purge` and confirm old webhook events and old recipients are removed.
10. Hit sign-in 11 times in a minute and confirm the 429.

## 11. Definition of done

- All specs in section 7 exist, failed before implementation, and pass after.
- Full suite green, RuboCop clean on touched files, Brakeman shows no new warnings.
- No Phase 2 or 2b spec was weakened. Section 8 edits are listed in the PR.
- README and `.env.example` list every new environment variable.
- The PR description lists the owner-visible changes, the new env vars, the Render plan change and its cost, and what was not done (reply composer, STOP confirmation message, live Meta sandbox test).
