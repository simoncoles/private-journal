# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  # Holds the decrypted private key for the duration of the request,
  # loaded from the session by ApplicationController.
  attribute :decrypted_private_key
  # Add other request-specific attributes here if needed, e.g.:
  # attribute :user
end
