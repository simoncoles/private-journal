class CreateEntryAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :entry_attachments do |t|
      t.references :entry, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type
      t.binary :encrypted_data, null: false
      t.text   :encrypted_key,   null: false
      t.string :iv,              null: false

      t.timestamps
    end
  end
end