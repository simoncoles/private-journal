class ApplicationController < ActionController::Base
  # Set Current attributes for the duration of the request
  before_action :set_current_request_details

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def set_current_request_details
    # Load the decrypted private key from the session into Current if it exists
    Current.decrypted_private_key = session[:decrypted_private_key]
  end

  # Redirects to unlock page if the journal is locked
  def require_unlocked_journal
    unless Current.decrypted_private_key.present?
      flash[:alert] = "You must unlock the journal to view this page."
      # Store the attempted URL to redirect back after unlock (optional but good UX)
      session[:intended_url] = request.original_url if request.get?
      redirect_to new_session_path # Redirect to unlock page
    end
  end
end
