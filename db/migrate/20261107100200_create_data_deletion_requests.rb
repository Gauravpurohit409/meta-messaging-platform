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
