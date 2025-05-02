class AttachmentsController < ApplicationController
  before_action :require_unlocked_journal
  before_action :set_attachment, only: [:download]

  # GET /attachments/:id/download
  def download
    # Get the decrypted data
    data = @attachment.data
    
    # Handle error messages that might be returned instead of actual data
    if data.to_s.start_with?("[Data ")
      flash[:alert] = "Unable to download: #{data}"
      redirect_to entry_path(@attachment.entry)
      return
    end
    
    # Send file data to the user
    send_data data, 
              filename: @attachment.name,
              type: @attachment.content_type,
              disposition: 'attachment'
  end

  private

  def set_attachment
    @attachment = Attachment.find(params[:id])
  end
end
