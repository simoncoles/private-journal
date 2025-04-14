# == Schema Information
#
# Table name: encryption_keys
#
#  id          :integer          not null, primary key
#  private_key :text             # Encrypted private key
#  public_key  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "openssl"
require "base64"

class EncryptionKey < ApplicationRecord
  # Generates a new RSA key pair, encrypts the private key with a passphrase,
  # and saves it to the database.
  #
  # @param passphrase [String] The passphrase to encrypt the private key.
  # @return [EncryptionKey] The newly created EncryptionKey instance.
  # @raise [ArgumentError] if the passphrase is blank.
  def self.generate_and_save(passphrase)
    raise ArgumentError, "Passphrase cannot be blank" if passphrase.blank?

    # Generate a new 2048-bit RSA key pair
    key_pair = OpenSSL::PKey::RSA.new(2048)
    public_key_pem = key_pair.public_key.to_pem
    private_key_pem = key_pair.to_pem # Use the full key pair PEM for encryption

    # Encrypt the private key using AES-256-CBC
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.encrypt
    # Use PBKDF2 to derive a key from the passphrase for better security
    salt = OpenSSL::Random.random_bytes(16) # Generate a random salt
    iter = 20000 # Number of iterations for PBKDF2
    key_len = cipher.key_len
    digest = OpenSSL::Digest.new("sha256")
    derived_key = OpenSSL::PKCS5.pbkdf2_hmac(passphrase, salt, iter, key_len, digest)

    cipher.key = derived_key
    iv = cipher.random_iv # Generate a random IV
    encrypted_private_key = cipher.update(private_key_pem) + cipher.final

    # Store salt, IV, and encrypted key together. Using Base64 encoding for binary data.
    # Format: Base64(salt):Base64(iv):Base64(encrypted_key)
    encrypted_data = [
      Base64.strict_encode64(salt),
      Base64.strict_encode64(iv),
      Base64.strict_encode64(encrypted_private_key)
    ].join(":")

    # Create and save the new EncryptionKey record
    create!(public_key: public_key_pem, private_key: encrypted_data)
  end

  # Decrypts the stored private key using the provided passphrase.
  #
  # @param passphrase [String] The passphrase used during encryption.
  # @return [OpenSSL::PKey::RSA] The decrypted private key object.
  # @raise [ArgumentError] if the passphrase is blank.
  # @raise [OpenSSL::Cipher::CipherError] if decryption fails (e.g., wrong passphrase).
  def decrypt_private_key(passphrase)
    raise ArgumentError, "Passphrase cannot be blank" if passphrase.blank?
    raise StandardError, "Private key data is missing" if private_key.blank?

    # Decode the stored data
    salt_b64, iv_b64, encrypted_key_b64 = private_key.split(":")
    raise StandardError, "Invalid private key data format" unless salt_b64 && iv_b64 && encrypted_key_b64

    salt = Base64.strict_decode64(salt_b64)
    iv = Base64.strict_decode64(iv_b64)
    encrypted_private_key = Base64.strict_decode64(encrypted_key_b64)

    # Decrypt the private key
    decipher = OpenSSL::Cipher.new("aes-256-cbc")
    decipher.decrypt
    # Use the same PBKDF2 parameters to derive the key
    iter = 20000 # Must match the encryption iteration count
    key_len = decipher.key_len
    digest = OpenSSL::Digest.new("sha256")
    derived_key = OpenSSL::PKCS5.pbkdf2_hmac(passphrase, salt, iter, key_len, digest)

    decipher.key = derived_key
    decipher.iv = iv

    begin
      decrypted_pem = decipher.update(encrypted_private_key) + decipher.final
      OpenSSL::PKey::RSA.new(decrypted_pem)
    rescue OpenSSL::Cipher::CipherError => e
      # Re-raise with a more specific message if decryption fails
      raise OpenSSL::Cipher::CipherError, "Decryption failed. Check passphrase. Original error: #{e.message}"
    rescue OpenSSL::PKey::RSAError => e
      # Handle potential issues with PEM parsing after decryption
      raise StandardError, "Failed to parse decrypted private key PEM. Original error: #{e.message}"
    end
  end

  # Basic presence validations
  validates :public_key, presence: { message: "cannot be blank" }
  validates :private_key, presence: { message: "cannot be blank" }
end
