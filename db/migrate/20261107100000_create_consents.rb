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
