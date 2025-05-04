class ApplicationController < ActionController::Base
  # Set Current attributes for the duration of the request
  before_action :set_current_request_details

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def set_current_request_details
    # Load the decrypted private key from the session into Current if it exists
    # Rails.logger.info "SET_CURRENT: Session ID: #{session.id.private_id rescue session.id}, Session Keys: #{session.keys.inspect}, Has Key?: #{session.key?(:decrypted_private_key)}" # Log session state # REMOVED
    Current.decrypted_private_key = session[:decrypted_private_key]
  end

  # Redirects to unlock page if the journal is locked
  def require_unlocked_journal
    # Rails.logger.info "REQUIRE_UNLOCK: Checking Current.decrypted_private_key. Present? #{Current.decrypted_private_key.present?}" # Log check state # REMOVED
    unless Current.decrypted_private_key.present?
      flash[:alert] = "You must unlock the journal to view this page."
      # Store the attempted URL to redirect back after unlock (optional but good UX)
      session[:intended_url] = request.original_url if request.get?
      redirect_to new_session_path # Redirect to unlock page
    end
  end

  # Add an around_action to ensure logging happens for every request
  around_action :ensure_request_logging

  # This method ensures logging happens for every request, even if set_current_request_details is skipped
  def ensure_request_logging
    # Log before the action
    Rails.logger.debug "SESSION DEBUG: #{session.to_hash.inspect}"
    Rails.logger.debug "CURRENT DEBUG: decrypted_private_key present? #{session[:decrypted_private_key].present?}"

    # Execute the action
    yield
  end
end
