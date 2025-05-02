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
class Attachment < ApplicationRecord
  belongs_to :entry
  belongs_to :encryption_key, optional: true # Make optional to support old schema during transition

  validates :name, presence: true
  validates :content_type, presence: true
  validate :file_size_under_limit

  before_validation :assign_encryption_key
  
  # Maximum file size: 10 MB
  MAX_FILE_SIZE = 10.megabytes

  # Custom validation to check file size
  def file_size_under_limit
    return unless @file_size_to_validate
    
    if @file_size_to_validate > MAX_FILE_SIZE
      errors.add(:base, "File size exceeds the limit of 10MB")
    end
  end
  
  # Automatically assign the latest encryption key if one isn't set
  # Uses the same logic as Entry model
  def assign_encryption_key
    # Skip if the column doesn't exist yet (during migration)
    return unless has_encryption_key_id_column?
    return unless encryption_key.nil?
    
    latest_key = EncryptionKey.order(created_at: :desc).first
    self.encryption_key = latest_key if latest_key
  end
  
  # Helper to check if the encryption_key_id column exists
  def has_encryption_key_id_column?
    self.class.column_names.include?('encryption_key_id')
  end
  
  # Helper to check if we have the new encryption fields
  def has_encryption_fields?
    has_encryption_key_id_column? && 
    self.class.column_names.include?('encrypted_key') && 
    self.class.column_names.include?('initialization_vector')
  end

  # Decrypt data using the private key stored in Current
  def data
    raw_data = self[:data]
    return nil if raw_data.nil? || raw_data.empty?

    # Check if we have a decryption key available
    return "[Data Encrypted - Key Unavailable]" unless Current.decrypted_private_key

    begin
      # Use the appropriate decryption method based on schema
      if has_encryption_fields? && self[:encrypted_key].present?
        # New format with separate fields
        return decrypt_with_separate_fields(raw_data)
      else
        # Legacy format with JSON blob
        return decrypt_legacy_format(raw_data)
      end
    rescue ArgumentError => e
      # This happens when the data is not valid Base64
      Rails.logger.error "Base64 decoding failed: #{e.message}"
      "[Data Corrupted - Invalid Encoding]"
    rescue OpenSSL::PKey::RSAError => e
      # This happens when RSA decryption fails
      Rails.logger.error "RSA decryption failed: #{e.message}"
      "[Data Decryption Failed - RSA Error]"
    rescue OpenSSL::Cipher::CipherError => e
      # This happens when AES decryption fails
      Rails.logger.error "AES decryption failed: #{e.message}"
      "[Data Decryption Failed - AES Error]"
    rescue StandardError => e
      # Catch any other errors
      Rails.logger.error "Decryption failed with unexpected error: #{e.message}"
      "[Data Decryption Failed - Unexpected Error]"
    end
  end
  
  # New decryption method with separate fields
  def decrypt_with_separate_fields(raw_data)
    # Decrypt the AES key using the RSA private key
    rsa_key = OpenSSL::PKey::RSA.new(Current.decrypted_private_key)
    
    # Extract the encrypted AES key and encrypted data
    encrypted_aes_key = Base64.strict_decode64(self[:encrypted_key])
    aes_key = rsa_key.private_decrypt(encrypted_aes_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
    
    # Extract the initialization vector
    iv = Base64.strict_decode64(self[:initialization_vector])
    
    # Decrypt the file data using the AES key
    decipher = OpenSSL::Cipher.new('aes-256-cbc')
    decipher.decrypt
    decipher.key = aes_key
    decipher.iv = iv
    
    # Return the decrypted file data
    decrypted_data = decipher.update(raw_data) + decipher.final
    return decrypted_data
  end
  
  # Legacy decryption method using JSON blob
  def decrypt_legacy_format(raw_data)
    # Parse the encrypted data structure
    encrypted_data_parts = JSON.parse(Base64.strict_decode64(raw_data))
    
    # Extract the encrypted AES key and encrypted data
    encrypted_aes_key = Base64.strict_decode64(encrypted_data_parts["key"])
    encrypted_data = Base64.strict_decode64(encrypted_data_parts["data"])
    iv = Base64.strict_decode64(encrypted_data_parts["iv"])
    
    # Decrypt the AES key using the RSA private key
    rsa_key = OpenSSL::PKey::RSA.new(Current.decrypted_private_key)
    aes_key = rsa_key.private_decrypt(encrypted_aes_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
    
    # Decrypt the file data using the AES key
    decipher = OpenSSL::Cipher.new('aes-256-cbc')
    decipher.decrypt
    decipher.key = aes_key
    decipher.iv = iv
    
    # Return the decrypted file data
    decrypted_data = decipher.update(encrypted_data) + decipher.final
    return decrypted_data
  end

  # Override the setter to intercept and encrypt data
  def data=(value)
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      self[:data] = nil
      if has_encryption_fields?
        self[:encrypted_key] = nil
        self[:initialization_vector] = nil
      end
      return
    end

    # Only encrypt if we have an encryption key and value is not already encrypted
    public_key = get_public_key
    if public_key && !value.to_s.start_with?("[Data ")
      begin
        # Get binary data if value is an uploaded file
        if value.respond_to?(:read)
          binary_data = value.read
        else
          binary_data = value
        end

        # Generate a random AES key
        cipher = OpenSSL::Cipher.new('aes-256-cbc')
        cipher.encrypt
        aes_key = cipher.random_key
        iv = cipher.random_iv
        
        # Encrypt the file data with AES
        encrypted_data = cipher.update(binary_data) + cipher.final
        
        # Encrypt the AES key with RSA
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key)
        encrypted_aes_key = rsa_public_key.public_encrypt(aes_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
        
        if has_encryption_fields?
          # New format: Store each component separately
          self[:data] = encrypted_data
          self[:encrypted_key] = Base64.strict_encode64(encrypted_aes_key)
          self[:initialization_vector] = Base64.strict_encode64(iv)
        else
          # Legacy format: Store as JSON blob
          encrypted_data_structure = {
            key: Base64.strict_encode64(encrypted_aes_key),
            data: Base64.strict_encode64(encrypted_data),
            iv: Base64.strict_encode64(iv)
          }
          self[:data] = Base64.strict_encode64(encrypted_data_structure.to_json)
        end
      rescue => e
        Rails.logger.error("Attachment encryption failed: #{e.message}")
        errors.add(:data, "could not be encrypted: #{e.message}")
        # Don't write anything on encryption failure
        throw(:abort) if errors.any?
      end
    else
      # If we don't have a key or this appears to be pre-encrypted data, store as-is
      self[:data] = value
    end
  end
  
  # Helper method to handle file uploads
  def file=(uploaded_file)
    if uploaded_file.present?
      self.name = uploaded_file.original_filename
      self.content_type = uploaded_file.content_type
      
      # Store file size for validation
      @file_size_to_validate = uploaded_file.size
      
      self.data = uploaded_file.read
    end
  end
  
  private
  
  # Get the public key from either the direct encryption_key relation
  # or via the entry's encryption_key
  def get_public_key
    if has_encryption_key_id_column? && encryption_key
      encryption_key.public_key
    elsif entry && entry.encryption_key
      entry.encryption_key.public_key
    else
      nil
    end
  end
end