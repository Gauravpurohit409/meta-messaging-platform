demo = User.find_or_initialize_by(email: "demo@marquee.test")
if demo.new_record?
  demo.name = "Asha Menon"
  demo.company = "Northwind Grocery"
  demo.password = "password123"
  demo.password_confirmation = "password123"
  demo.save!
end

demo.whatsapp_account.update!(display_phone: "+91 33 4000 2210") if demo.whatsapp_account.display_phone.blank?

def seed_template(user, attributes)
  template = user.templates.find_or_initialize_by(name: attributes.fetch(:name), language: attributes.fetch(:language, "en_US"))
  template.update!(attributes.merge(user: user))
  template
end

order_ready = seed_template(demo, {
  name: "order_ready",
  language: "en_US",
  category: "UTILITY",
  status: "approved",
  header_text: "Northwind Grocery",
  body: "Hi {{1}}, order {{2}} is packed and waiting at the Ballygunge counter.",
  footer_text: "Reply here if you need a later slot.",
  buttons: [ { "type" => "URL", "text" => "Track order", "url" => "https://northwind.example/orders/{{1}}" } ],
  example_values: { "body_1" => "Asha", "body_2" => "NW-1042", "url_0" => "NW-1042" },
  meta_template_id: "demo_order_ready",
  submitted_at: 2.days.ago,
  approved_at: 2.days.ago + 3.hours,
  rejection_reason: nil
})

seed_template(demo, {
  name: "festive_hamper",
  language: "en_US",
  category: "MARKETING",
  status: "pending",
  header_text: nil,
  body: "Hello {{1}}, the Diwali hamper is back and orders close on {{2}}.",
  footer_text: "Northwind Grocery, Ballygunge",
  buttons: [ { "type" => "URL", "text" => "Shop hampers", "url" => "https://northwind.example/hampers" } ],
  example_values: { "body_1" => "Asha", "body_2" => "Friday" },
  meta_template_id: "demo_festive_hamper",
  submitted_at: 1.hour.ago,
  approved_at: nil,
  rejection_reason: nil
})

seed_template(demo, {
  name: "payment_nudge",
  language: "en_US",
  category: "UTILITY",
  status: "rejected",
  header_text: nil,
  body: "Hi {{1}}, pay invoice {{2}} now or we will take legal action.",
  footer_text: nil,
  buttons: [],
  example_values: { "body_1" => "Asha", "body_2" => "INV-88" },
  meta_template_id: "demo_payment_nudge",
  submitted_at: 3.days.ago,
  approved_at: nil,
  rejection_reason: "ABUSIVE_CONTENT — threatening a customer with legal action is not allowed."
})

seed_template(demo, {
  name: "milk_subscription",
  language: "en_US",
  category: "UTILITY",
  status: "draft",
  header_text: nil,
  body: "Hi {{1}}, your {{2}} milk crate is on tomorrow's route.",
  footer_text: "Skip a day by replying SKIP.",
  buttons: [],
  example_values: { "body_1" => "Asha", "body_2" => "toned" },
  meta_template_id: nil,
  submitted_at: nil,
  approved_at: nil,
  rejection_reason: nil
})

saturday = demo.campaigns.find_or_initialize_by(name: "Saturday pickup reminders")
saturday.update!(
  template: order_ready,
  status: "completed",
  default_parameters: {},
  total_recipients: 4,
  sent_count: 3,
  delivered_count: 3,
  read_count: 1,
  failed_count: 1,
  started_at: 1.day.ago,
  completed_at: 1.day.ago + 10.minutes,
  failure_reason: nil
)

[
  [ "919830001111", { "body_1" => "Meera", "body_2" => "NW-2041", "url_0" => "NW-2041" }, "delivered", nil ],
  [ "919830002222", { "body_1" => "Rahul", "body_2" => "NW-2042", "url_0" => "NW-2042" }, "read", nil ],
  [ "919830003333", { "body_1" => "Isha", "body_2" => "NW-2043", "url_0" => "NW-2043" }, "delivered", nil ],
  [ "919830000000", { "body_1" => "Dev", "body_2" => "NW-2044", "url_0" => "NW-2044" }, "failed", "Message undeliverable. Demo mode fails numbers that end in 0000." ]
].each do |phone, parameters, status, error_message|
  recipient = saturday.recipients.find_or_initialize_by(phone_number: phone)
  recipient.update!(
    parameters: parameters,
    status: status,
    message_id: "wamid.demo.seed.#{phone}",
    error_message: error_message,
    error_code: status == "failed" ? "131026" : nil,
    sent_at: status == "failed" ? nil : 1.day.ago,
    delivered_at: %w[delivered read].include?(status) ? 1.day.ago + 2.minutes : nil,
    read_at: status == "read" ? 1.day.ago + 8.minutes : nil
  )
end

restock = demo.campaigns.find_or_initialize_by(name: "Evening restock ping")
restock.update!(
  template: order_ready,
  status: "draft",
  default_parameters: { "body_1" => "neighbour", "body_2" => "NW-3300", "url_0" => "NW-3300" },
  total_recipients: 3,
  sent_count: 0,
  delivered_count: 0,
  read_count: 0,
  failed_count: 0,
  started_at: nil,
  completed_at: nil,
  scheduled_at: nil,
  failure_reason: nil
)

[
  [ "919811110101", { "body_1" => "Meera", "body_2" => "NW-3301", "url_0" => "NW-3301" } ],
  [ "919822220202", { "body_1" => "Rahul", "body_2" => "NW-3302", "url_0" => "NW-3302" } ],
  [ "919833330000", { "body_1" => "Isha", "body_2" => "NW-3303", "url_0" => "NW-3303" } ]
].each do |phone, parameters|
  recipient = restock.recipients.find_or_initialize_by(phone_number: phone)
  next unless recipient.new_record?

  recipient.update!(parameters: parameters, status: "pending")
end

puts "Demo desk ready: demo@marquee.test / password123"
