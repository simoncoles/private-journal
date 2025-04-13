class Entry < ApplicationRecord
  # Override the getter for the 'content' attribute
  def content
    encrypted_content = read_attribute(:content)
    return nil if encrypted_content.blank?

    private_key = Rails.application.config.encryption_keys&.[](:private_key)
    unless private_key
      Rails.logger.error("Private key not loaded, cannot decrypt content for Entry ##{id}")
      # Depending on requirements, you might return the encrypted content,
      # return an error message, or raise an exception.
      return "[Content Encrypted - Key Unavailable]"
    end

    begin
      decoded_content = Base64.strict_decode64(encrypted_content)
      private_key.private_decrypt(decoded_content)
    rescue OpenSSL::PKey::RSAError => e
      Rails.logger.error("Decryption failed for Entry ##{id}: #{e.message}")
      "[Content Decryption Failed]"
    rescue ArgumentError => e # Handle potential Base64 decoding errors
      Rails.logger.error("Base64 decoding failed for Entry ##{id}: #{e.message}")
      "[Content Corrupted - Invalid Encoding]"
    end
  end

  # Override the setter for the 'content' attribute
  def content=(new_content)
    if new_content.blank?
      write_attribute(:content, nil)
      return
    end

    public_key = Rails.application.config.encryption_keys&.[](:public_key)
    unless public_key
      Rails.logger.error("Public key not loaded, cannot encrypt content for Entry ##{id || 'new'}")
      # Decide how to handle this - maybe raise an error to prevent saving unencrypted data?
      raise "Cannot save entry: Encryption key unavailable."
    end

    begin
      encrypted_content = public_key.public_encrypt(new_content.to_s)
      encoded_content = Base64.strict_encode64(encrypted_content)
      write_attribute(:content, encoded_content)
    rescue OpenSSL::PKey::RSAError => e
      Rails.logger.error("Encryption failed for Entry ##{id || 'new'}: #{e.message}")
      raise "Cannot save entry: Encryption failed."
    end
  end
end
