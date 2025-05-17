class AttachmentsController < ApplicationController
  before_action :require_unlocked_journal
  before_action :set_attachment, only: [ :download, :destroy ]

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
              disposition: "attachment"
  end

  # DELETE /attachments/:id
  def destroy
    entry = @attachment.entry
    @attachment.destroy!

    respond_to do |format|
      format.html { redirect_to edit_entry_path(entry), notice: "Attachment was successfully removed." }
      format.json { head :no_content }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@attachment) }
    end
  end

  private

  def set_attachment
    @attachment = Attachment.find(params[:id])
  end
end
