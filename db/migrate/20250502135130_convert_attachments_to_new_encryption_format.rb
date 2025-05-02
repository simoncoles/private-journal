class ConvertAttachmentsToNewEncryptionFormat < ActiveRecord::Migration[8.0]
  def up
    # This migration only affects existing attachments with data in the old format
    execute <<-SQL
      SELECT id, data, entry_id FROM attachments WHERE data IS NOT NULL AND data != ''
    SQL
    
    # Get and iterate through all existing attachments to convert them
    attachments = ActiveRecord::Base.connection.select_all("SELECT id, data, entry_id FROM attachments WHERE data IS NOT NULL AND data != ''")
    
    attachments.each do |attachment|
      begin
        # Skip if already in new format or empty
        next if attachment['data'].nil? || attachment['data'].empty?
        
        # Attempt to decode and parse the existing data format
        begin
          encoded_data = attachment['data']
          data_structure = JSON.parse(Base64.strict_decode64(encoded_data))
          
          # Extract components
          encrypted_key = data_structure["key"]
          encrypted_data = Base64.strict_decode64(data_structure["data"])
          initialization_vector = data_structure["iv"]
          
          # Get the encryption key id from the entry
          entry_id = attachment['entry_id']
          encryption_key_id = ActiveRecord::Base.connection.select_value("SELECT encryption_key_id FROM entries WHERE id = #{entry_id}")
          
          # Update with the new format
          execute <<-SQL
            UPDATE attachments 
            SET 
              data = x'#{encrypted_data.unpack1('H*')}',
              encrypted_key = '#{encrypted_key}',
              initialization_vector = '#{initialization_vector}',
              encryption_key_id = #{encryption_key_id}
            WHERE id = #{attachment['id']}
          SQL
        rescue => e
          puts "Error converting attachment #{attachment['id']}: #{e.message}"
          # Skip this attachment if conversion fails
          next
        end
      rescue => e
        puts "Error processing attachment #{attachment['id']}: #{e.message}"
        # Skip this attachment
        next
      end
    end
  end

  def down
    # Converting back would be complex and risky - this is a one-way migration
    raise ActiveRecord::IrreversibleMigration
  end
end
