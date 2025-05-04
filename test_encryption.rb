puts "=== Testing Entry Encryption ==="

# Check for encryption keys
key_count = EncryptionKey.count
puts "Found #{key_count} encryption key(s) in the database"

if key_count == 0
  puts "No encryption keys found. Let's create one with a simple test key."

  # Generate a simple key pair just for testing
  key_pair = OpenSSL::PKey::RSA.new(2048)
  public_key_pem = key_pair.public_key.to_pem
  private_key_pem = key_pair.to_pem

  # Create a new encryption key in the database
  encryption_key = EncryptionKey.create!(
    public_key: public_key_pem,
    private_key: private_key_pem # Storing unencrypted for testing only!
  )

  puts "Created a test encryption key with ID: #{encryption_key.id}"
end

# Get the latest encryption key
latest_key = EncryptionKey.order(created_at: :desc).first
puts "Using encryption key ID: #{latest_key.id}"

# Create a new entry
test_content = "This is a test entry that should be encrypted with the public key."
entry = Entry.new(
  entry_date: Time.current,
  content: test_content,
  category: "Diary"
)

# Print debugging information
puts "\nBefore save:"
puts "- entry.encryption_key_id: #{entry.encryption_key_id.inspect}"
puts "- entry.encryption_key: #{entry.encryption_key.inspect}"
puts "- entry[:content] (raw): #{entry[:content].inspect}"

# Save the entry
if entry.save
  puts "\nEntry was saved successfully with ID: #{entry.id}"

  # Fetch the entry from the database to check raw content
  raw_entry = Entry.find(entry.id)

  puts "\nAfter save:"
  puts "- raw_entry.encryption_key_id: #{raw_entry.encryption_key_id.inspect}"
  puts "- raw_entry[:content] (raw database value): #{raw_entry[:content].inspect}"

  # Check if content appears to be Base64 encoded (a sign of encryption)
  if raw_entry[:content]
    is_base64 = raw_entry[:content].match?(/^[A-Za-z0-9+\/]+=*$/)
    puts "- Content appears to be Base64 encoded: #{is_base64}"

    # Check if the raw content is different from the original input
    is_different = raw_entry[:content] != test_content
    puts "- Content differs from original input: #{is_different}"

    if is_base64 && is_different
      puts "=> Content appears to be encrypted properly"
    else
      puts "=> Content does NOT appear to be encrypted"
    end
  else
    puts "- Content is nil or empty"
  end
else
  puts "\nEntry could not be saved:"
  puts entry.errors.full_messages.join("\n")
end

puts "\nComplete"
