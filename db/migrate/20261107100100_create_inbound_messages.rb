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
