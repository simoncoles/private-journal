# == Schema Information
#
# Table name: attachments
#
#  id                    :integer          not null, primary key
#  content_type          :string
#  data                  :binary
#  encrypted_key         :text
#  initialization_vector :text
#  name                  :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  encryption_key_id     :integer          not null
#  entry_id              :integer          not null
#
# Indexes
#
#  index_attachments_on_encryption_key_id  (encryption_key_id)
#  index_attachments_on_entry_id           (entry_id)
#
# Foreign Keys
#
#  encryption_key_id  (encryption_key_id => encryption_keys.id)
#  entry_id           (entry_id => entries.id)
#
require "test_helper"
require "stringio"

class AttachmentTest < ActiveSupport::TestCase
  # Setup runs before each test
  setup do
    # Generate a key pair for this test run
    rsa_key = OpenSSL::PKey::RSA.new(2048)
    @private_key_pem = rsa_key.to_pem
    @public_key_pem = rsa_key.public_key.to_pem

    # Before creating a new key, make sure old data is cleaned up to avoid foreign key issues
    Entry.destroy_all
    EncryptionKey.destroy_all

    # Create an EncryptionKey record for entries to use
    @encryption_key = EncryptionKey.create!(
      public_key: @public_key_pem,
      private_key: @private_key_pem
    )

    # Create an entry for our attachments
    @entry = Entry.create!(
      entry_date: Time.current, 
      content: "Test entry", 
      encryption_key: @encryption_key
    )

    # Set the private key in Current for decryption operations
    Current.decrypted_private_key = @private_key_pem
  end

  # Teardown runs after each test
  teardown do
    # Clean up Current attribute
    Current.reset
    # First delete entries, then encryption keys to avoid foreign key constraint violations
    Entry.destroy_all
    EncryptionKey.destroy_all
  end

  test "should validate presence of name and content_type" do
    attachment = Attachment.new(entry: @entry)
    assert_not attachment.valid?
    assert_includes attachment.errors[:name], "can't be blank"
    assert_includes attachment.errors[:content_type], "can't be blank"
  end

  test "should belong to an entry" do
    attachment = Attachment.new(name: "test.txt", content_type: "text/plain")
    assert_not attachment.valid?
    assert_includes attachment.errors[:entry], "must exist"
    
    # Only check encryption_key requirement if the column exists
    if Attachment.column_names.include?('encryption_key_id')
      # The belongs_to is now optional during transition
      assert_not_includes attachment.errors[:encryption_key], "must exist"
    end
  end

  test "should validate file size" do
    # Create a mock file that exceeds the size limit
    oversized_file = StringIO.new("x" * (Attachment::MAX_FILE_SIZE + 1))
    def oversized_file.size
      Attachment::MAX_FILE_SIZE + 1
    end
    def oversized_file.original_filename
      "large_file.txt"
    end
    def oversized_file.content_type
      "text/plain"
    end

    attachment = Attachment.new(entry: @entry)
    attachment.file = oversized_file
    assert_not attachment.valid?
    assert_includes attachment.errors[:base], "File size exceeds the limit of 10MB"
  end

  test "should encrypt data using hybrid encryption" do
    # Create test file content
    file_content = "This is test file content"
    file = StringIO.new(file_content)
    def file.original_filename
      "test.txt"
    end
    def file.content_type
      "text/plain"
    end
    
    # Create and save the attachment
    attachment = nil
    if Attachment.column_names.include?('encryption_key_id')
      # New schema format
      attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    else
      # Legacy schema format
      attachment = Attachment.new(entry: @entry)
    end
    
    attachment.file = file
    assert attachment.save
    
    # Verify the data is not stored as plaintext
    raw_data = attachment[:data]
    assert_not_nil raw_data
    assert_not_equal file_content, raw_data
    
    # Encryption format check is conditional based on schema
    if Attachment.column_names.include?('encrypted_key') && 
       Attachment.column_names.include?('initialization_vector')
      # New schema - check direct fields
      assert_not_nil attachment[:encrypted_key]
      assert_not_nil attachment[:initialization_vector]
    else
      # Legacy schema - check JSON format
      begin
        # This should be a Base64-encoded JSON string with encryption data
        decoded = Base64.strict_decode64(raw_data)
        data_structure = JSON.parse(decoded)
        
        # Basic check for JSON structure
        assert data_structure.key?("key"), "Encrypted data should have an AES key"
        assert data_structure.key?("data"), "Encrypted data should have encrypted content"
        assert data_structure.key?("iv"), "Encrypted data should have an initialization vector"
      rescue => e
        flunk "Data is not in expected legacy format: #{e.message}"
      end
    end
  end
  
  test "should decrypt data correctly" do
    skip "Skipping test until all migrations are applied" unless Attachment.column_names.include?('encryption_key_id')
    
    # Create and encrypt test file
    original_content = "This is content that should be encrypted and then decrypted"
    file = StringIO.new(original_content)
    def file.original_filename
      "test.txt"
    end
    def file.content_type
      "text/plain"
    end
    
    # Create and save attachment
    attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    attachment.file = file
    assert attachment.save
    
    # Reload from database
    reloaded_attachment = Attachment.find(attachment.id)
    
    # Verify decryption works correctly
    decrypted_data = reloaded_attachment.data
    assert_equal original_content, decrypted_data
  end
  
  test "should handle large file encryption and decryption" do
    skip "Skipping test until all migrations are applied" unless Attachment.column_names.include?('encryption_key_id')
    
    # Create large content (larger than what direct RSA could handle)
    large_content = "A" * 1_000_000  # 1MB of data
    file = StringIO.new(large_content)
    def file.original_filename
      "large_file.txt"
    end
    def file.content_type
      "text/plain"
    end
    def file.size
      1_000_000
    end
    
    # Create and save attachment
    attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    attachment.file = file
    
    # The save should succeed with hybrid encryption
    assert_nothing_raised do
      assert attachment.save
    end
    
    # Check the decryption
    reloaded_attachment = Attachment.find(attachment.id)
    assert_equal large_content, reloaded_attachment.data
  end
  
  test "should return error message if private key is unavailable for decryption" do
    skip "Skipping test until all migrations are applied" unless Attachment.column_names.include?('encryption_key_id')
    
    # Create and encrypt a file normally
    file = StringIO.new("Test content")
    def file.original_filename
      "test.txt"
    end
    def file.content_type
      "text/plain"
    end
    
    attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    attachment.file = file
    assert attachment.save
    
    # Remove the private key
    original_key = Current.decrypted_private_key
    Current.decrypted_private_key = nil
    
    # Try to decrypt
    reloaded_attachment = Attachment.find(attachment.id)
    assert_equal "[Data Encrypted - Key Unavailable]", reloaded_attachment.data
    
    # Restore key for other tests
    Current.decrypted_private_key = original_key
  end
  
  test "should return error message if decryption fails due to corruption" do
    # Create and encrypt a file
    file = StringIO.new("Test content for corruption test")
    def file.original_filename
      "test.txt"
    end
    def file.content_type
      "text/plain"
    end
    
    # Create attachment with the appropriate model for the schema
    attachment = nil
    if Attachment.column_names.include?('encryption_key_id')
      attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    else
      attachment = Attachment.new(entry: @entry)
    end
    
    attachment.file = file
    assert attachment.save
    
    # Corrupt the data based on schema
    if Attachment.column_names.include?('encrypted_key')
      # New schema - corrupt the encrypted key
      attachment.update_column(:encrypted_key, Base64.strict_encode64("invalid key data"))
    else
      # Legacy schema - corrupt the JSON data
      encoded_data = attachment[:data]
      begin
        decoded = Base64.strict_decode64(encoded_data)
        data = JSON.parse(decoded)
        data["key"] = Base64.strict_encode64("invalid key data")
        corrupted = Base64.strict_encode64(data.to_json)
        attachment.update_column(:data, corrupted)
      rescue => e
        flunk "Failed to corrupt legacy data format: #{e.message}"
      end
    end
    
    # Try to decrypt the corrupted data
    reloaded_attachment = Attachment.find(attachment.id)
    
    # We expect an error message instead of content
    error_message = reloaded_attachment.data
    assert error_message.is_a?(String), "Error message should be a string"
    assert_match /Decryption Failed|Corrupted/, error_message, "Error message should indicate decryption failure"
  end
  
  test "should automatically assign latest encryption key if none specified" do
    # Skip this test if we don't have the encryption_key_id column
    skip "Skipping auto key assignment test for old schema" unless Attachment.column_names.include?('encryption_key_id')
    
    # Create a test file
    file = StringIO.new("Test content for auto key assignment")
    def file.original_filename
      "auto_key_test.txt"
    end
    def file.content_type
      "text/plain"
    end
    
    # Create attachment without specifying encryption key
    attachment = Attachment.new(entry: @entry)
    attachment.file = file
    assert attachment.valid?
    assert attachment.save
    
    # Verify the encryption key was automatically assigned
    assert_not_nil attachment.encryption_key_id
    assert_equal @encryption_key.id, attachment.encryption_key_id
  end
end
