require 'openssl'

Rails.application.config.to_prepare do
  # Use a simple flag to ensure keys are loaded only once per process
  unless defined?(Rails.application.config.encryption_keys_loaded) && Rails.application.config.encryption_keys_loaded
    encryption_keys = {}
    begin
      # Ensure the table exists before trying to query it (useful for initial setup/migrations)
      if ActiveRecord::Base.connection.table_exists? 'encryption_keys'
        key_record = EncryptionKey.first

        if key_record
          begin
            encryption_keys[:private_key] = OpenSSL::PKey::RSA.new(key_record.private_key)
            encryption_keys[:public_key] = OpenSSL::PKey::RSA.new(key_record.public_key)
            Rails.logger.info "Successfully loaded encryption keys from database."
          rescue OpenSSL::PKey::RSAError => e
            Rails.logger.error "Failed to parse encryption keys from database: #{e.message}"
          end
        else
          Rails.logger.warn "No encryption keys found in the database. Run 'rake encryption:generate_and_seed_keys' to create them."
        end
      else
         Rails.logger.warn "'encryption_keys' table does not exist yet. Skipping key loading."
      end

      Rails.application.config.encryption_keys = encryption_keys
      Rails.application.config.encryption_keys_loaded = true # Set the flag

      # Validate that both keys are loaded, especially in production
      if Rails.env.production? && (!encryption_keys[:private_key] || !encryption_keys[:public_key])
        raise "Encryption keys could not be loaded properly from the database! Check the 'encryption_keys' table and logs."
      end

    rescue ActiveRecord::NoDatabaseError
      Rails.logger.warn "Database does not exist yet. Skipping key loading."
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred while loading encryption keys: #{e.message}"
      # Consider raising in production if keys are critical
      # raise "Failed to initialize encryption keys!" if Rails.env.production?
    end
  end
end
