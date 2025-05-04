# == Schema Information
#
# Table name: entries
#
#  id                :integer          not null, primary key
#  category          :string           default("Diary"), not null
#  content           :text
#  entry_date        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  encryption_key_id :integer          not null
#
# Indexes
#
#  index_entries_on_encryption_key_id  (encryption_key_id)
#
# Foreign Keys
#
#  encryption_key_id  (encryption_key_id => encryption_keys.id)
#
class Entry < ApplicationRecord
  belongs_to :encryption_key
  has_many :attachments, dependent: :destroy

  # Choices for the category field in entries
  CATEGORIES = %w[Diary ChatGPT].freeze

  # Ensures category is either "Diary" or "ChatGPT", defaulting to "Diary"
  # Only validate content presence if we're not explicitly setting it to blank/nil
  validates :content, presence: true, if: -> { !content.nil? && content_changed? && !content.to_s.empty? }
  validates :category, inclusion: { in: CATEGORIES, message: "%{value} is not a valid category" }

  # Assign default category and encryption key before validation
  before_validation :set_default_category
  before_validation :assign_encryption_key

  # Decrypt content using the private key stored in Current
  def content
    raw_content = self[:content]
    return nil if raw_content.nil? || raw_content.empty?

    # Check if we have a decryption key available
    return "[Content Encrypted - Key Unavailable]" unless Current.decrypted_private_key

    begin      # Parse the encrypted data structure
      encrypted_data_parts = JSON.parse(Base64.strict_decode64(raw_content))
      
      # Extract the encrypted AES key and encrypted data
      encrypted_aes_key = Base64.strict_decode64(encrypted_data_parts["key"])
      encrypted_content = Base64.strict_decode64(encrypted_data_parts["data"])
      iv = Base64.strict_decode64(encrypted_data_parts["iv"])
      
      # Decrypt the AES key using the RSA private key
      rsa_key = OpenSSL::PKey::RSA.new(Current.decrypted_private_key)
      aes_key = rsa_key.private_decrypt(encrypted_aes_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
      
      # Decrypt the content using the AES key
      decipher = OpenSSL::Cipher.new('aes-256-cbc')
      decipher.decrypt
      decipher.key = aes_key
      decipher.iv = iv
      
      # Return the decrypted content - ensure it's UTF-8 encoded for special characters
      decrypted_content = decipher.update(encrypted_content) + decipher.final
      decrypted_content.force_encoding('UTF-8')
      return decrypted_content
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      "[Content Corrupted - Invalid Format]"
    rescue ArgumentError => e
      # This happens when the content is not valid Base64
      Rails.logger.error "Base64 decoding failed: #{e.message}"
      "[Content Corrupted - Invalid Encoding]"
    rescue OpenSSL::PKey::RSAError => e
      # This happens when RSA decryption fails
      Rails.logger.error "RSA decryption failed: #{e.message}"
      "[Content Decryption Failed - RSA Error]"
    rescue OpenSSL::Cipher::CipherError => e
      # This happens when AES decryption fails
      Rails.logger.error "AES decryption failed: #{e.message}"
      "[Content Decryption Failed - AES Error]"
    rescue StandardError => e
      # Catch any other errors
      Rails.logger.error "Decryption failed with unexpected error: #{e.message}"
      "[Content Decryption Failed - Unexpected Error]"
    end
  end

  # Override the setter to intercept and encrypt content
  def content=(value)
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      self[:content] = nil
      # Make sure we don't try to encrypt nil or empty content
      @plaintext_content = nil
      return
    end
    
    # Store the plaintext content for later encryption
    @plaintext_content = value
    
    # If this is already an encrypted message, store as-is
    if value.to_s.start_with?("[Content ")
      self[:content] = value
    else
      # We'll encrypt in before_save callback after encryption_key is assigned
      # For now, just store in instance variable and leave self[:content] untouched
    end
  end
  
  # Add this callback to encrypt content after all validations
  before_save :encrypt_content
  
  # Method to encrypt the stored plaintext content using hybrid encryption
  def encrypt_content
    return unless @plaintext_content
    return if @plaintext_content.to_s.start_with?("[Content ")
    
    # Only encrypt if we have a key assigned
    if encryption_key
      begin
        Rails.logger.debug "Encrypting content using key ID #{encryption_key.id}"
        
        # Generate a random AES key for symmetric encryption
        cipher = OpenSSL::Cipher.new('aes-256-cbc')
        cipher.encrypt
        aes_key = cipher.random_key
        iv = cipher.random_iv
        
        # Encrypt the content with AES
        encrypted_content = cipher.update(@plaintext_content) + cipher.final
        
        # Encrypt the AES key with RSA
        rsa_public_key = OpenSSL::PKey::RSA.new(encryption_key.public_key)
        encrypted_aes_key = rsa_public_key.public_encrypt(aes_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
        
        # Create a structure to store all encrypted parts
        encrypted_data_structure = {
          key: Base64.strict_encode64(encrypted_aes_key),
          data: Base64.strict_encode64(encrypted_content),
          iv: Base64.strict_encode64(iv)
        }
        
        # Store the entire structure as Base64-encoded JSON
        self[:content] = Base64.strict_encode64(encrypted_data_structure.to_json)
        Rails.logger.debug "Content encrypted using hybrid encryption and stored as Base64"
      rescue => e
        Rails.logger.error("Encryption failed: #{e.message}")
        errors.add(:content, "could not be encrypted: #{e.message}")
        throw(:abort) # Don't continue with the save
      end
    else
      Rails.logger.error("Cannot encrypt content: No encryption key assigned")
      errors.add(:base, "Cannot encrypt content: No encryption key available")
      throw(:abort) # Don't continue with the save
    end
  end

  private

  # Remove the old assign_and_encrypt_content method since we handle encryption in the setter
  def assign_and_encrypt_content
    # We'll now skip this method as we handle encryption directly in the content= method
    # This is left empty to keep callbacks intact - could be removed later
  end

  def set_default_category
    self.category ||= "Diary"
  end

  def assign_encryption_key
    # Find the latest encryption key if one isn't already associated
    latest_key = EncryptionKey.order(created_at: :desc).first
    self.encryption_key = latest_key if self.encryption_key.nil?
    
    # Log assignment for debugging
    Rails.logger.debug "Assigned encryption_key: #{self.encryption_key.inspect}"

    # If we couldn't find a key and content needs encryption, add an error
    if self.encryption_key.nil? && content.present? && !content.to_s.start_with?("[Content ")
      errors.add(:base, "No encryption key available. Please run 'rake encryption:generate_and_seed_keys' to create one.")
      throw(:abort) # Prevent the save from continuing
    end
  end
end
