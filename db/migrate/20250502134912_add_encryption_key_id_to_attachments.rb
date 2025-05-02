class AddEncryptionKeyIdToAttachments < ActiveRecord::Migration[8.0]
  def change
    add_reference :attachments, :encryption_key, foreign_key: true, null: false, index: true
  end
end
