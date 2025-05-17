class AddEncryptionColumnsToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :encrypted_aes_key, :text
    add_column :entries, :initialization_vector, :text
  end
end
