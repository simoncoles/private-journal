class AddEncryptionKeyToEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :entries, :encryption_key, null: false, foreign_key: true
  end
end
