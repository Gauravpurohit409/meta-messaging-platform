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
