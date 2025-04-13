class CreateEncryptionKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :encryption_keys do |t|
      t.text :public_key
      t.text :private_key

      t.timestamps
    end
  end
end
