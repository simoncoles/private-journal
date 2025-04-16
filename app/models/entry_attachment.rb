class EntryAttachment < ApplicationRecord
  belongs_to :entry

  # Encrypt and attach an uploaded file
  # uploaded_io is an ActionDispatch::Http::UploadedFile or similar
  def attach_and_encrypt(uploaded_io)
    public_key = Rails.application.config.encryption_keys&.[](:public_key)
    unless public_key
      Rails.logger.error("Public key not loaded, cannot encrypt attachment for EntryAttachment")
      raise "Cannot attach file: Encryption key unavailable."
    end

    # Symmetric encryption for arbitrary file sizes
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.encrypt
    sym_key = cipher.random_key
    iv_bin  = cipher.random_iv

    # Encrypt file contents
    data = uploaded_io.read
    encrypted_data = cipher.update(data) + cipher.final

    # Encrypt the symmetric key with RSA
    encrypted_key = public_key.public_encrypt(sym_key)

    # Store attributes
    self.filename       = uploaded_io.original_filename
    self.content_type   = uploaded_io.content_type
    self.encrypted_data = encrypted_data
    self.iv             = Base64.strict_encode64(iv_bin)
    self.encrypted_key  = Base64.strict_encode64(encrypted_key)
  end

  # Decrypt and return raw file data, or nil on failure
  def download
    private_key = Rails.application.config.encryption_keys&.[](:private_key)
    unless private_key
      Rails.logger.error("Private key not loaded, cannot decrypt attachment ##{id}")
      return nil
    end

    # Recover symmetric key
    encrypted_key_bin = Base64.strict_decode64(encrypted_key)
    sym_key = private_key.private_decrypt(encrypted_key_bin)

    # Decode iv and decrypt data
    iv_bin = Base64.strict_decode64(iv)
    decipher = OpenSSL::Cipher.new("aes-256-cbc")
    decipher.decrypt
    decipher.key = sym_key
    decipher.iv  = iv_bin
    decipher.update(encrypted_data) + decipher.final
  rescue StandardError => e
    Rails.logger.error("Attachment decryption failed for ##{id}: #{e.class} - #{e.message}")
    nil
  end
end