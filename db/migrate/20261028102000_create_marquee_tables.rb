class CreateMarqueeTables < ActiveRecord::Migration[8.0]
  def change
    create_table :whatsapp_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :waba_id
      t.string :phone_number_id
      t.text :access_token
      t.string :verify_token, null: false
      t.string :display_phone
      t.boolean :demo_mode, null: false, default: true
      t.timestamps
    end

    create_table :templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :meta_template_id
      t.string :name, null: false
      t.string :language, null: false, default: "en_US"
      t.string :category, null: false, default: "UTILITY"
      t.string :status, null: false, default: "draft"
      t.string :header_text
      t.text :body, null: false
      t.string :footer_text
      t.jsonb :buttons, null: false, default: []
      t.jsonb :example_values, null: false, default: {}
      t.text :rejection_reason
      t.datetime :submitted_at
      t.datetime :approved_at
      t.timestamps
    end
    add_index :templates, [ :user_id, :name, :language ], unique: true
    add_index :templates, :status
    add_index :templates, :meta_template_id

    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: true
      t.references :template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :default_parameters, null: false, default: {}
      t.text :failure_reason
      t.datetime :scheduled_at
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_recipients, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :delivered_count, null: false, default: 0
      t.integer :read_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.timestamps
    end
    add_index :campaigns, :status

    create_table :campaign_recipients do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.jsonb :parameters, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.string :message_id
      t.string :error_code
      t.text :error_message
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.timestamps
    end
    add_index :campaign_recipients, [ :campaign_id, :phone_number ], unique: true
    add_index :campaign_recipients, :message_id

    create_table :webhook_events do |t|
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :processed, null: false, default: false
      t.text :error_message
      t.timestamps
    end
  end
end
