class MoveAttachmentDataToFilesystem < ActiveRecord::Migration[8.0]
  def up
    # Make sure the storage directory exists
    storage_dir = Rails.root.join('storage', 'attachments')
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
    
    # Get all attachments with data in database
    attachments = Attachment.where.not(data: nil)
    puts "Moving #{attachments.count} attachments to file system..."
    
    attachments.each do |attachment|
      begin
        # Skip if already moved
        if attachment.file_path.present? && File.exist?(storage_dir.join(attachment.file_path))
          puts "  - Skipping attachment #{attachment.id} (already moved)"
          next
        end
        
        # Create entry-specific directory if it doesn't exist
        entry_dir = File.join(storage_dir, attachment.entry_id.to_s)
        FileUtils.mkdir_p(entry_dir) unless Dir.exist?(entry_dir)
        
        # Generate a file path if needed
        if attachment.file_path.blank?
          timestamp = Time.current.to_i
          random = SecureRandom.hex(8)
          sanitized_name = attachment.name.gsub(/[^a-zA-Z0-9\.\-]/, '_')
          attachment.file_path = "#{attachment.entry_id}/#{timestamp}_#{random}_#{sanitized_name}"
        end
        
        # Write the data to the file system
        file_path = storage_dir.join(attachment.file_path)
        
        # Write the data from the database to the file
        File.binwrite(file_path, attachment.data)
        puts "  - Moved attachment #{attachment.id} to #{attachment.file_path}"
        
        # Update the attachment record - clear data field since it's now in file system
        attachment.update_column(:data, nil)
      rescue => e
        puts "  - Error moving attachment #{attachment.id}: #{e.message}"
      end
    end
  end

  def down
    # Since we're keeping the metadata (encrypted_key, initialization_vector),
    # we can't automatically restore the actual data from files back to database.
    puts "WARNING: Cannot automatically restore attachment data from filesystem to database."
    puts "Please manually handle this operation if needed."
  end
end