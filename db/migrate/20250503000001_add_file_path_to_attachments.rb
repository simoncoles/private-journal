class AddFilePathToAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :attachments, :file_path, :string
    add_index :attachments, :file_path, unique: true
  end
end
