class ReorganizeExistingAttachments < ActiveRecord::Migration[8.0]
  def up
    # Only process attachments that have been moved to the filesystem but don't have entry ID in their path
    storage_dir = Rails.root.join('storage', 'attachments')
    
    # Skip if storage directory doesn't exist yet
    return unless Dir.exist?(storage_dir)
    
    attachments = Attachment.where.not(file_path: nil).where("data IS NULL")
    puts "Reorganizing #{attachments.count} existing attachments to entry-based directories..."
    
    attachments.each do |attachment|
      begin
        # Skip if the file path already includes the entry ID
        if attachment.file_path.start_with?("#{attachment.entry_id}/")
          puts "  - Skipping attachment #{attachment.id} (already in correct directory)"
          next
        end
        
        # Get the old file path
        old_path = storage_dir.join(attachment.file_path)
        
        # Skip if the file doesn't exist
        unless File.exist?(old_path)
          puts "  - Skipping attachment #{attachment.id} (file not found at #{old_path})"
          next
        end
        
        # Create entry-specific directory if it doesn't exist
        entry_dir = File.join(storage_dir, attachment.entry_id.to_s)
        FileUtils.mkdir_p(entry_dir) unless Dir.exist?(entry_dir)
        
        # Generate new file path with entry ID
        filename = File.basename(attachment.file_path)
        new_file_path = "#{attachment.entry_id}/#{filename}"
        new_path = storage_dir.join(new_file_path)
        
        # Move the file to the new location
        FileUtils.mv(old_path, new_path)
        puts "  - Moved attachment #{attachment.id} from #{attachment.file_path} to #{new_file_path}"
        
        # Update the attachment record with the new file path
        attachment.update_column(:file_path, new_file_path)
      rescue => e
        puts "  - Error reorganizing attachment #{attachment.id}: #{e.message}"
      end
    end
  end

  def down
    puts "WARNING: Cannot automatically restore the previous directory structure."
    puts "This migration is not reversible."
  end
end
