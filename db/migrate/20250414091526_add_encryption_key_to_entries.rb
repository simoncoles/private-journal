class AddEncryptionKeyToEntries < ActiveRecord::Migration[8.0]
  def up
    # Add the column allowing nulls initially
    add_reference :entries, :encryption_key, null: true, foreign_key: true

    # Ensure Entry and EncryptionKey models are available if needed (optional, but safe)
    # You might need to define minimal versions of these models if they are complex
    # or if the migration runs before the models are fully loaded.
    # class Entry < ApplicationRecord; end
    # class EncryptionKey < ApplicationRecord; end

    # Find or create a default encryption key
    # Adjust this logic based on how your EncryptionKeys are managed
    default_key = EncryptionKey.first_or_create! # Example: Creates one if none exist

    # Update existing entries in batches to avoid memory issues
    Entry.in_batches.update_all(encryption_key_id: default_key.id)

    # Change the column to not allow nulls
    change_column_null :entries, :encryption_key_id, false
  end

  def down
    remove_reference :entries, :encryption_key, null: false, foreign_key: true
  end
end
