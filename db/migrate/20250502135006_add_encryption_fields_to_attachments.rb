class AddEncryptionFieldsToAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :attachments, :encrypted_key, :text
    add_column :attachments, :initialization_vector, :text
  end
end
