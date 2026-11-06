require "rails_helper"
require "json"

RSpec.describe "Meta::EmbeddedSignup" do
  let(:user) { create(:user) }
  let(:account) { user.whatsapp_account }

  around do |example|
    keys = %w[META_APP_ID META_EMBEDDED_SIGNUP_CONFIG_ID META_APP_SECRET META_GRAPH_VERSION]
    saved = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["META_APP_ID"] = "1234567890"
    ENV["META_EMBEDDED_SIGNUP_CONFIG_ID"] = "987654321"
    ENV["META_APP_SECRET"] = "app-secret"
    ENV["META_GRAPH_VERSION"] = "v26.0"
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  before do
    allow(Faraday).to receive(:new).and_raise("Meta was called")
  end

  describe ".connect" do
    it "exchanges the code, subscribes the app, registers the number, and stores the business" do
      requests = stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222")
        stub_waba(stubs, "111", "name" => "Northwind Grocery")
        stub_phone(stubs, "222", "display_phone_number" => "+1 555 0100", "verified_name" => "Northwind", "quality_rating" => "GREEN", "messaging_limit_tier" => "TIER_1K")
      end

      connected = Meta::EmbeddedSignup.connect(
        account: account,
        code: " good_CODE-1 ",
        waba_id: " 111 ",
        phone_number_id: " 222 "
      )

      expect(connected).to be(true)
      account.reload
      expect(account.demo_mode).to be(false)
      expect(account.access_token).to eq("EAA-new")
      expect(account.waba_id).to eq("111")
      expect(account.phone_number_id).to eq("222")
      expect(account.business_name).to eq("Northwind Grocery")
      expect(account.display_phone).to eq("+1 555 0100")
      expect(account.quality_rating).to eq("GREEN")
      expect(account.messaging_limit).to eq("TIER_1K")
      expect(account.connected_at).to be_present
      expect(account.registration_pin).to match(/\A\d{6}\z/)

      token_call, subscribe_call, register_call = requests
      expect(token_call.url.path).to include("/v26.0/oauth/access_token")
      expect(token_call.params["code"]).to eq("good_CODE-1")
      expect(token_call.params["client_id"]).to eq("1234567890")
      expect(token_call.params["client_secret"]).to eq("app-secret")
      expect(token_call.request_headers["Authorization"]).to be_blank

      expect(subscribe_call.url.path).to end_with("/111/subscribed_apps")
      expect(subscribe_call.request_headers["Authorization"]).to eq("Bearer EAA-new")

      register_body = parsed_body(register_call)
      expect(register_call.url.path).to end_with("/222/register")
      expect(register_body["messaging_product"]).to eq("whatsapp")
      expect(register_body["pin"]).to eq(account.registration_pin)
      expect(register_call.request_headers["Authorization"]).to eq("Bearer EAA-new")

      raw_token = raw_column(account, "access_token")
      raw_pin = raw_column(account, "registration_pin")
      expect(raw_token).not_to include("EAA-new")
      expect(raw_pin).not_to include(account.registration_pin)
    end

    it "uses META_GRAPH_VERSION in every call" do
      ENV["META_GRAPH_VERSION"] = "v99.0"
      requests = stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222")
        stub_waba(stubs, "111", "name" => "Northwind")
        stub_phone(stubs, "222", "display_phone_number" => "+1 555 0100")
      end

      expect(connect).to be(true)
      expect(requests.map { |env| env.url.path }).to all(include("/v99.0/"))
    end

    it "treats an already-registered number as connected" do
      stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222", status: 400, body: meta_error("Phone number already registered", 133016))
        stub_waba(stubs, "111", "name" => "Northwind")
        stub_phone(stubs, "222", "display_phone_number" => "+1 555 0100")
      end

      expect(connect).to be(true)
      expect(account.reload.access_token).to eq("EAA-new")
      expect(account.demo_mode).to be(false)
    end

    it "stays connected when the business details cannot be loaded" do
      stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222")
        stubs.get(%r{/111}) { [ 500, json_headers, meta_error("details down", 1) ] }
      end

      expect(connect).to be(true)
      expect(account.reload.access_token).to eq("EAA-new")
      expect(account.business_name).to be_nil
      expect(account.demo_mode).to be(false)
    end

    it "lets the same desk connect the same WABA again" do
      account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "old-token")
      stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222", status: 400, body: meta_error("Phone number already registered", 133016))
        stub_waba(stubs, "111", "name" => "Northwind")
        stub_phone(stubs, "222", "display_phone_number" => "+1 555 0100")
      end

      expect(connect).to be(true)
      expect(account.reload.access_token).to eq("EAA-new")
    end

    it "does not connect when Embedded Signup is not configured" do
      ENV["META_APP_ID"] = ""

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to match(/not configured/i)
      expect(account.reload.access_token).to be_nil
    end

    it "does not connect a WABA that belongs to another desk" do
      other = create(:user).whatsapp_account
      other.update!(demo_mode: false, waba_id: "111", phone_number_id: "333", access_token: "theirs")

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to match(/already connected/i)
      expect(account.reload.access_token).to be_nil
      expect(other.reload.access_token).to eq("theirs")
    end

    it "does not connect a phone number that belongs to another desk" do
      other = create(:user).whatsapp_account
      other.update!(demo_mode: false, waba_id: "999", phone_number_id: "222", access_token: "theirs")

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to match(/already connected/i)
      expect(other.reload.waba_id).to eq("999")
    end

    [
      [ "", "111", "222", "missing code" ],
      [ "   ", "111", "222", "blank code" ],
      [ "bad code", "111", "222", "code with a space" ],
      [ "abc&client_secret=x", "111", "222", "code that would change the query" ],
      [ "a" * 2001, "111", "222", "code longer than 2000 characters" ],
      [ "good_CODE-1", "abc", "222", "waba id that is not digits" ],
      [ "good_CODE-1", "12 3", "222", "waba id with a space" ],
      [ "good_CODE-1", "1" * 33, "222", "waba id longer than 32 digits" ],
      [ "good_CODE-1", "111", "22-2", "phone number id that is not digits" ],
      [ "good_CODE-1", "111", "", "missing phone number id" ]
    ].each do |code, waba_id, phone_number_id, reason|
      it "rejects a #{reason} before calling Meta" do
        expect(Meta::EmbeddedSignup.connect(account: account, code: code, waba_id: waba_id, phone_number_id: phone_number_id)).to be(false)
        expect(account.reload.demo_mode).to be(true)
        expect(account.access_token).to be_nil
      end
    end

    it "does not keep the token when subscribing the app fails" do
      stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stubs.post(%r{/subscribed_apps\z}) { [ 400, json_headers, meta_error("subscribe failed", 100) ] }
      end

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to include("subscribe failed")
      expect(account.reload.access_token).to be_nil
      expect(account.demo_mode).to be(true)
      expect(account.waba_id).to be_nil
    end

    it "does not keep the token when the registration PIN is rejected" do
      stub_graph do |stubs|
        stub_token(stubs, "EAA-new")
        stub_subscribe(stubs, "111")
        stub_register(stubs, "222", status: 400, body: meta_error("PIN mismatch", 133005))
      end

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to include("PIN mismatch")
      expect(account.reload.access_token).to be_nil
      expect(account.registration_pin).to be_nil
    end

    it "does not keep the token when Meta returns an empty token" do
      stub_graph do |stubs|
        stubs.get(%r{/oauth/access_token}) { [ 200, json_headers, { "access_token" => "" }.to_json ] }
      end

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to match(/token/i)
      expect(account.reload.access_token).to be_nil
    end

    it "does not keep the token when the code is invalid" do
      stub_graph do |stubs|
        stubs.get(%r{/oauth/access_token}) { [ 400, json_headers, meta_error("Invalid code", 100) ] }
      end

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to include("Invalid code")
      expect(account.reload.access_token).to be_nil
    end

    it "reports that Meta could not be reached" do
      stub_graph do |stubs|
        stubs.get(%r{/oauth/access_token}) { raise Faraday::ConnectionFailed, "down" }
      end

      expect(connect).to be(false)
      expect(account.errors.full_messages.join).to match(/Could not reach Meta/)
      expect(account.reload.access_token).to be_nil
    end
  end

  describe ".disconnect" do
    it "unsubscribes the app and wipes the saved connection" do
      account.update!(
        demo_mode: false,
        waba_id: "111",
        phone_number_id: "222",
        access_token: "old-token",
        business_name: "Northwind",
        registration_pin: "123456"
      )
      requests = stub_graph do |stubs|
        stubs.delete(%r{/subscribed_apps\z}) { [ 200, json_headers, { "success" => true }.to_json ] }
      end

      expect(Meta::EmbeddedSignup.disconnect(account)).to be(true)

      expect(requests.first.url.path).to end_with("/111/subscribed_apps")
      expect(requests.first.request_headers["Authorization"]).to eq("Bearer old-token")
      account.reload
      expect(account.demo_mode).to be(true)
      expect(account.access_token).to be_nil
      expect(account.registration_pin).to be_nil
      expect(account.waba_id).to be_nil
      expect(account.phone_number_id).to be_nil
      expect(account.business_name).to be_nil
      expect(account.restricted).to be(false)
    end

    it "wipes the local connection when Meta refuses the unsubscribe" do
      account.update!(demo_mode: false, waba_id: "111", phone_number_id: "222", access_token: "old-token")
      stub_graph do |stubs|
        stubs.delete(%r{/subscribed_apps\z}) { [ 500, json_headers, meta_error("unavailable", 1) ] }
      end

      expect(Meta::EmbeddedSignup.disconnect(account)).to be(false)
      expect(account.errors.full_messages.join).to include("unavailable")
      expect(account.reload.access_token).to be_nil
      expect(account.demo_mode).to be(true)
      expect(account.waba_id).to be_nil
    end

    it "does not call Meta for a demo desk" do
      expect(Meta::EmbeddedSignup.disconnect(account)).to be(true)
      expect(account.reload.demo_mode).to be(true)
    end
  end

  def connect
    Meta::EmbeddedSignup.connect(account: account, code: "good_CODE-1", waba_id: "111", phone_number_id: "222")
  end

  def stub_graph
    requests = []
    Thread.current[:embedded_signup_requests] = requests
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs
    allow(Faraday).to receive(:new).and_wrap_original do |original, *args, &user_block|
      url = args.first.is_a?(Hash) ? args.first[:url].to_s : args.first.to_s
      next original.call(*args, &user_block) unless url.include?("graph.facebook.com")

      original.call(url: "https://graph.facebook.com") do |builder|
        user_block&.call(builder)
        builder.adapter :test, stubs
      end
    end
    requests
  end

  def stub_token(stubs, token)
    stubs.get(%r{/oauth/access_token}) do |env|
      record(env)
      [ 200, json_headers, { "access_token" => token }.to_json ]
    end
  end

  def stub_subscribe(stubs, waba_id, status: 200, body: { "success" => true }.to_json)
    stubs.post(%r{/#{waba_id}/subscribed_apps\z}) do |env|
      record(env)
      [ status, json_headers, body ]
    end
  end

  def stub_register(stubs, phone_number_id, status: 200, body: { "success" => true }.to_json)
    stubs.post(%r{/#{phone_number_id}/register\z}) do |env|
      record(env)
      [ status, json_headers, body ]
    end
  end

  def stub_waba(stubs, waba_id, payload)
    stubs.get(%r{/#{waba_id}(\z|\?)}) do |env|
      record(env)
      [ 200, json_headers, payload.to_json ]
    end
  end

  def stub_phone(stubs, phone_number_id, payload)
    stubs.get(%r{/#{phone_number_id}(\z|\?)}) do |env|
      record(env)
      [ 200, json_headers, payload.to_json ]
    end
  end

  def record(env)
    Thread.current[:embedded_signup_requests] << env
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end

  def meta_error(message, code)
    { "error" => { "message" => message, "code" => code } }.to_json
  end

  def parsed_body(env)
    body = env.body
    body = JSON.parse(body) if body.is_a?(String) && body.present?
    body.to_h.stringify_keys
  end

  def raw_column(account, column)
    WhatsappAccount.connection.select_value(
      "SELECT #{column} FROM whatsapp_accounts WHERE id = #{account.id.to_i}"
    ).to_s
  end
end
