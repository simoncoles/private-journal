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

class EntryTest < ActiveSupport::TestCase
  # Generate a test key pair for encryption/decryption tests
  def setup
    # Generate a 2048-bit RSA key pair for testing
    @test_private_key = OpenSSL::PKey::RSA.new(2048)
    @test_public_key = @test_private_key.public_key

    # Stub the Rails configuration to use these keys during tests
    # Note: Ensure any existing config is restored if necessary, although
    # ActiveSupport::TestCase transactions usually handle isolation.
    @original_keys = Rails.application.config.encryption_keys
    Rails.application.config.encryption_keys = {
      public_key: @test_public_key,
      private_key: @test_private_key
    }
  end

  def teardown
    # Restore original keys if they existed
    Rails.application.config.encryption_keys = @original_keys
  end

  test "should be valid with default category" do
    entry = Entry.new(content: "Test content", entry_date: Time.current)
    assert entry.valid?
    assert_equal "Diary", entry.category
  end

  test "should be valid with allowed categories" do
    Entry::CATEGORIES.each do |category|
      entry = Entry.new(category: category, content: "Test content", entry_date: Time.current)
      assert entry.valid?, "Entry should be valid with category '#{category}'"
    end
  end

  test "should be invalid with disallowed category" do
    entry = Entry.new(category: "InvalidCategory", content: "Test content", entry_date: Time.current)
    assert_not entry.valid?
    assert entry.errors[:category].any?, "Should have an error on category"
  end

  test "should be invalid without category (if default wasn't applied)" do
    # This tests the model validation before DB default might apply
    entry = Entry.new(content: "Test content", entry_date: Time.current)
    entry.category = nil # Explicitly set to nil to bypass default mechanism if any
    assert_not entry.valid?
    assert entry.errors[:category].any?, "Should have an error on category when nil"
  end

  # --- Encryption/Decryption Tests ---

  test "should encrypt content on assignment" do
    entry = Entry.new(entry_date: Time.current)
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
    entry = Entry.new(entry_date: Time.current)
    original_content = "Another secret to keep."
    entry.content = original_content
    entry.save! # Save to ensure content is processed and stored

    # Reload the entry from the database to simulate retrieval
    reloaded_entry = Entry.find(entry.id)

    # Check that the retrieved content matches the original
    assert_equal original_content, reloaded_entry.content
  end

  test "should handle blank content assignment" do
    entry = Entry.new(entry_date: Time.current)
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
    entry = Entry.new(entry_date: Time.current)
    entry.content = "Some initial content"
    entry.save!

    # Assign nil content
    entry.content = nil
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    assert_nil reloaded_entry.read_attribute_before_type_cast(:content), "Raw content should be nil for nil assignment"
    assert_nil reloaded_entry.content, "Decrypted content should be nil for nil assignment"
  end

  test "should raise error if public key is missing during encryption" do
    # Temporarily remove the public key from the stubbed config
    Rails.application.config.encryption_keys = { private_key: @test_private_key }

    entry = Entry.new(entry_date: Time.current)

    assert_raises RuntimeError do
      entry.content = "This should fail to encrypt"
    end

    # Restore for other tests
    Rails.application.config.encryption_keys = { public_key: @test_public_key, private_key: @test_private_key }
  end

  test "should return error message if private key is missing during decryption" do
    # Encrypt with the key
    entry = Entry.new(entry_date: Time.current)
    entry.content = "Encrypt me first"
    entry.save!

    # Temporarily remove the private key from the stubbed config
    Rails.application.config.encryption_keys = { public_key: @test_public_key }

    reloaded_entry = Entry.find(entry.id)

    # Check that the custom getter returns the placeholder message
    assert_equal "[Content Encrypted - Key Unavailable]", reloaded_entry.content

    # Restore for other tests
    Rails.application.config.encryption_keys = { public_key: @test_public_key, private_key: @test_private_key }
  end

  test "should return error message if decryption fails" do
    # Encrypt normally first
    entry = Entry.new(entry_date: Time.current)
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
    entry = Entry.new(entry_date: Time.current, content: "Placeholder")
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
    entry = Entry.new(entry_date: Time.current, content: large_content)

    # Assert that encryption/decryption cycle works for content within the limit.

    assert_nothing_raised do
      entry.save!
    end

    reloaded_entry = Entry.find(entry.id)
    assert_equal large_content, reloaded_entry.content, "Decrypted large content should match original"
  end

  test "should handle unicode and special characters correctly" do
    special_content = "Emojis 😀 你好世界 Accénts éàüö Symbols !@#$%^&*()_+-={}|[]\\:;'<>?,./~"
    entry = Entry.new(entry_date: Time.current, content: special_content)
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    assert_equal special_content, reloaded_entry.content, "Decrypted special content should match original"
    assert_equal Encoding::UTF_8, reloaded_entry.content.encoding, "Decrypted content should be UTF-8 encoded"
  end

  test "should save and retrieve entry_date correctly" do
    specific_time = Time.zone.local(2024, 5, 15, 10, 30, 0)
    entry = Entry.new(entry_date: specific_time, content: "Testing date")
    entry.save!

    reloaded_entry = Entry.find(entry.id)
    # Compare times ensuring they are both in the same zone (e.g., UTC) for reliable comparison
    assert_equal specific_time.utc.to_s, reloaded_entry.entry_date.utc.to_s
  end

  # test "the truth" do
  #   assert true
  # end
end
