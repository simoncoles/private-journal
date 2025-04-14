# == Schema Information
#
# Table name: entries
#
#  id              :integer          not null, primary key
#  category        :string           default("Diary"), not null
#  content         :text
#  entry_date      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  encryption_key_id :integer
#
class Entry < ApplicationRecord
  belongs_to :encryption_key

  CATEGORIES = %w[Diary ChatGPT].freeze

  # Ensures category is either "Diary" or "ChatGPT", defaulting to "Diary"
  validates :content, presence: true
  validates :category, inclusion: { in: CATEGORIES, message: "%{value} is not a valid category" }

  # Assign key and encrypt before validation runs
  before_validation :assign_and_encrypt_content
  before_validation :set_default_category

  # Decrypt content using the private key stored in Current
  def decrypted_content
    return nil unless content.present? && Current.decrypted_private_key

    begin
      # Load the private key stored in Current after unlock
      private_key = OpenSSL::PKey::RSA.new(Current.decrypted_private_key)

      # Decode the Base64 content from the database
      encrypted_data = Base64.decode64(self.content)

      # Decrypt the content
      private_key.private_decrypt(encrypted_data)
    rescue OpenSSL::PKey::RSAError => e
      # Handle decryption errors (e.g., wrong key, corrupted data)
      Rails.logger.error("Decryption failed for Entry #{id}: #{e.message}")
      "Error decrypting content." # Or return nil, or raise an error
    end
  end

  private

  # Encrypt content using the public key of the latest EncryptionKey
  def assign_and_encrypt_content
    # Find the latest encryption key if one isn't already associated
    self.encryption_key ||= EncryptionKey.order(created_at: :desc).first

    # Ensure we have a key
    unless self.encryption_key
      # The belongs_to validation should catch this first, but check defensively
      errors.add(:base, "No encryption key available.")
      throw(:abort) # Prevent saving if no key is found
    end

    # Ensure we have content to encrypt and it's not already encrypted (simple check)
    # This check might need refinement depending on how updates are handled.
    # For simplicity, we re-encrypt on every save if content is present.
    return unless self.content.present?

    begin
      # Load the public key
      public_key = OpenSSL::PKey::RSA.new(self.encryption_key.public_key)

      # Encrypt the content
      encrypted_data = public_key.public_encrypt(self.content)

      # Store the encrypted content (Base64 encoded for database storage)
      self.content = Base64.encode64(encrypted_data)
    rescue OpenSSL::PKey::RSAError => e
      # Handle encryption errors
      Rails.logger.error("Encryption failed for Entry: #{e.message}")
      errors.add(:content, "could not be encrypted: #{e.message}")
      throw(:abort) # Prevent saving if encryption fails
    end
  end

  def set_default_category
    self.category ||= "Diary"
  end
end
