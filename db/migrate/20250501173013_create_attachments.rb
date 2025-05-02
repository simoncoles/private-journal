class CreateAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :attachments do |t|
      t.string :name
      t.string :content_type
      t.binary :data
      t.references :entry, null: false, foreign_key: true

      t.timestamps
    end
  end
end
