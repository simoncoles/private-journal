require "openssl"

namespace :encryption do
  desc "Generates a new RSA key pair and saves it to the EncryptionKey table if none exists."
  task generate_and_seed_keys: :environment do
    if EncryptionKey.any?
      puts "Encryption keys already exist in the database. No action taken."
    else
      puts "Generating new RSA 4096-bit key pair..."
      key = OpenSSL::PKey::RSA.new(4096)

      private_key_pem = key.to_pem
      public_key_pem = key.public_key.to_pem

      puts "Saving keys to the database..."
      EncryptionKey.create!(
        private_key: private_key_pem,
        public_key: public_key_pem
      )

      puts "Successfully generated and saved encryption keys to the database."
    end
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
    puts e.backtrace
    puts "Failed to generate or save keys."
  end
end
