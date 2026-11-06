class AddEmbeddedSignupToWhatsappAccounts < ActiveRecord::Migration[8.0]
  def change
    change_table :whatsapp_accounts, bulk: true do |t|
      t.string :business_name
      t.string :quality_rating
      t.string :messaging_limit
      t.string :pin_phone_number_id
      t.text :registration_pin
      t.text :policy_notice
      t.datetime :connected_at
      t.boolean :restricted, null: false, default: false
      t.boolean :reconnect_required, null: false, default: false
    end

    add_index :whatsapp_accounts, :waba_id, unique: true
    add_index :whatsapp_accounts, :phone_number_id, unique: true
  end
end
