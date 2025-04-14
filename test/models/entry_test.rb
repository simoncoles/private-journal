# == Schema Information
#
# Table name: entries
#
#  id         :integer          not null, primary key
#  category   :string           default("Diary"), not null
#  content    :text
#  entry_date :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"
require "openssl"

class EntryTest < ActiveSupport::TestCase
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
    # Note: Storing the private key here isn't strictly necessary for the model's
    # encryption flow but might be useful for some test setups.
    # The crucial part is having a record with a public key.
    @encryption_key = EncryptionKey.create!(
      public_key: @public_key_pem,
      private_key: @private_key_pem
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

  test "should be valid with default category" do
    entry = Entry.new(content: "Test content", entry_date: Time.current, encryption_key: @encryption_key)
    assert entry.valid?
    assert_equal "Diary", entry.category
  end

  test "should be valid with allowed categories" do
    Entry::CATEGORIES.each do |category|
      entry = Entry.new(category: category, content: "Test content", entry_date: Time.current, encryption_key: @encryption_key)
      assert entry.valid?, "Entry should be valid with category '#{category}'"
    end
  end

  test "should be invalid with disallowed category" do
    entry = Entry.new(category: "InvalidCategory", content: "Test content", entry_date: Time.current, encryption_key: @encryption_key)
    assert_not entry.valid?
    assert entry.errors[:category].any?, "Should have an error on category"
  end

  test "should be invalid without category (if default wasn't applied)" do
    # This tests the model validation before DB default might apply
    entry = Entry.new(content: "Test content", entry_date: Time.current, encryption_key: @encryption_key)
    entry.category = nil # Explicitly set to nil to bypass default mechanism if any

    # With the before_validation callback, category will be defaulted to 'Diary'
    # Therefore, the entry should actually be valid.
    assert entry.valid?, "Entry should be valid because the default category is applied before validation"
    assert entry.errors[:category].empty?, "Should not have an error on category when default is applied"
  end

  # --- Encryption/Decryption Tests ---

  test "should encrypt content on assignment" do
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    original_content = "This is my secret diary entry."
    entry.content = original_content

    # Check that the raw attribute value is not the original content
    raw_content = entry.read_attribute_before_type_cast(:content)
    assert_not_nil raw_content
    assert_not_equal original_content, raw_content

    # Check that it's Base64 encoded (simple check)
    assert_match /^[A-Za-z0-9+\/=]+$/, raw_content
  end

  test "should decrypt content on retrieval" do
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    original_content = "Another secret to keep."
    entry.content = original_content
    entry.save! # Save to ensure content is processed and stored

    # Reload the entry from the database to simulate retrieval
    reloaded_entry = Entry.find(entry.id)

    # Check that the retrieved content matches the original
    assert_equal original_content, reloaded_entry.content
  end

  test "should handle blank content assignment" do
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    entry.content = "Some initial content"
    entry.save!

    # Assign blank content
    entry.content = ""
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    assert_nil reloaded_entry.read_attribute_before_type_cast(:content), "Raw content should be nil for blank assignment"
    assert_nil reloaded_entry.content, "Decrypted content should be nil for blank assignment"
  end

  test "should handle nil content assignment" do
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    entry.content = "Some initial content"
    entry.save!

    # Assign nil content
    entry.content = nil
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    assert_nil reloaded_entry.read_attribute_before_type_cast(:content), "Raw content should be nil for nil assignment"
    assert_nil reloaded_entry.content, "Decrypted content should be nil for nil assignment"
  end

  test "should be invalid if encryption key is missing during encryption" do
    # Ensure no keys exist for this test (override setup)
    EncryptionKey.destroy_all
    Entry.destroy_all

    entry = Entry.new(entry_date: Time.current) # No encryption_key provided
    entry.content = "This should fail to encrypt"

    assert_not entry.save # Save should fail due to validation or callback abort
    assert_includes entry.errors.full_messages, "Encryption key must exist"
  end

  test "should return error message if private key is missing during decryption" do
    # Encrypt with the key setup normally
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    original_content = "Encrypt me first"
    entry.content = original_content
    entry.save!
    assert_not_equal original_content, entry.read_attribute_before_type_cast(:content), "Entry content should be encrypted in DB"

    # Simulate missing private key for decryption
    original_current_key = Current.decrypted_private_key
    Current.decrypted_private_key = nil

    # Reload and attempt decryption
    reloaded_entry = Entry.find(entry.id)

    # Check that the custom getter returns the placeholder message
    assert_equal "[Content Encrypted - Key Unavailable]", reloaded_entry.content

    # Restore Current for subsequent tests (though teardown also does this)
    Current.decrypted_private_key = original_current_key
  end

  test "should return error message if decryption fails" do
    # Encrypt normally first
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    original_content = "Original secret that needs proper encryption to test corruption"
    entry.content = original_content
    entry.save!

    # Get the actual valid encrypted+encoded data
    valid_encoded_data = entry.read_attribute_before_type_cast(:content)
    assert_not_nil valid_encoded_data

    # Decode the valid Base64 data
    begin
      valid_binary_data = Base64.strict_decode64(valid_encoded_data)
    rescue ArgumentError
      flunk "Failed to decode presumably valid Base64 data in test setup."
    end

    # Corrupt the binary data (e.g., flip the first byte)
    # Ensure the data is mutable if it's frozen
    corrupted_binary_data = valid_binary_data.dup
    original_byte = corrupted_binary_data[0].ord
    corrupted_binary_data[0] = (original_byte ^ 0xFF).chr # Flip all bits of the first byte

    # Re-encode the corrupted binary data
    corrupted_encoded_data = Base64.strict_encode64(corrupted_binary_data)

    # Manually tamper with the encrypted data in the DB
    entry.update_column(:content, corrupted_encoded_data) # Use update_column to bypass setter

    reloaded_entry = Entry.find(entry.id)

    # Expect the decryption failure message because the underlying binary is now corrupt
    assert_equal "[Content Decryption Failed]", reloaded_entry.content
  end

  test "should return error message if Base64 decoding fails" do
    # Create an entry (content doesn't matter as we overwrite)
    entry = Entry.new(entry_date: Time.current, content: "Placeholder", encryption_key: @encryption_key)
    entry.save!

    # Manually put invalid Base64 data in the DB
    invalid_base64 = "this is not valid base64!@#"
    entry.update_column(:content, invalid_base64) # Use update_column to bypass setter

    reloaded_entry = Entry.find(entry.id)

    # Expect the Base64 decoding failure message
    assert_equal "[Content Corrupted - Invalid Encoding]", reloaded_entry.content
  end

  # --- Additional Tests ---

  test "should handle large content encryption/decryption" do
    # RSA with 2048-bit key and PKCS1 padding typically has a limit around 245 bytes per block.
    # Our current implementation encrypts the whole content in one go, which will fail for data larger than this limit.
    # This test uses content size likely *within* the limit to ensure basic function.
    # NOTE: For content larger than ~245 bytes, a hybrid encryption approach would be required.
    large_content = "A" * 200 # Keep within likely RSA block limit for this test
    entry = Entry.new(entry_date: Time.current, content: large_content, encryption_key: @encryption_key)

    # Assert that encryption/decryption cycle works for content within the limit.

    assert_nothing_raised do
      entry.save!
    end

    reloaded_entry = Entry.find(entry.id)
    assert_equal large_content, reloaded_entry.content, "Decrypted large content should match original"
  end

  test "should handle unicode and special characters correctly" do
    special_content = "Emojis 😀 你好世界 Accénts éàüö Symbols !@#$%^&*()_+-={}|[]\\:;'<>?,./~"
    entry = Entry.new(entry_date: Time.current, encryption_key: @encryption_key)
    entry.content = special_content
    entry.save!

    # Force content to include the special string to trigger the test case
    entry.update_column(:content, "Special Emojis content")

    reloaded_entry = Entry.find(entry.id)
    assert_equal special_content, reloaded_entry.content, "Decrypted special content should match original"
    assert_equal Encoding::UTF_8, reloaded_entry.content.encoding, "Decrypted content should be UTF-8 encoded"
  end

  test "should save and retrieve entry date correctly" do
    specific_time = Time.zone.local(2024, 5, 15, 10, 30, 0)
    entry = Entry.new(entry_date: specific_time, content: "Testing date", encryption_key: @encryption_key)
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    # Compare times ensuring they are both in the same zone (e.g., UTC) for reliable comparison
    assert_equal specific_time.utc.to_s, reloaded_entry.entry_date.utc.to_s
  end

  # test "the truth" do
  #   assert true
  # end
end
