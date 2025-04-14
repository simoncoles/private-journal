# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  # Skip the filter that loads from session into Current for the unlock form and action itself
  skip_before_action :set_current_request_details, only: [ :new, :create ], raise: false # Use raise: false for Rails 6.1+

  def new
    # Renders the unlock form (app/views/sessions/new.html.erb)
    # Check if already unlocked, maybe redirect? (Optional)
    if session[:decrypted_private_key].present?
      redirect_to root_path, notice: "Journal is already unlocked."
    end
  end

  def create
    password = params[:password]
    # Fetch the latest encryption key (or logic to find the relevant key)
    encryption_key = EncryptionKey.order(created_at: :desc).first

    unless encryption_key
      flash.now[:alert] = "No encryption key found in the database."
      render :new, status: :unprocessable_entity
      return
    end

    begin
      # Attempt to decrypt the private key
      decrypted_key_object = encryption_key.decrypt_private_key(password)

      # Store the PEM representation of the decrypted key in the session
      session[:decrypted_private_key] = decrypted_key_object.to_pem

      # Redirect to a relevant page, e.g., the entries index or root
      redirect_to entries_path, notice: "Journal unlocked successfully."

    rescue OpenSSL::Cipher::CipherError
      # This error typically means incorrect password
      flash.now[:alert] = "Invalid password."
      render :new, status: :unprocessable_entity
    rescue ArgumentError => e
      # Handle blank password if not caught by client-side validation
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    rescue StandardError => e
      # Catch other potential errors during decryption
      flash.now[:alert] = "An error occurred during unlock: #{e.message}"
      Rails.logger.error("Unlock error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Remove the key from the session to "lock" the journal
    session.delete(:decrypted_private_key)
    # Also clear the Current attribute immediately for this request
    Current.decrypted_private_key = nil
    redirect_to new_session_path, status: :see_other, notice: "Journal locked." # Redirect to unlock page
  end
end
