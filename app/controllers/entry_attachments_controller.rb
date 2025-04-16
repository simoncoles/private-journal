class EntryAttachmentsController < ApplicationController
  before_action :set_entry
  before_action :set_attachment, only: [:download]

  # GET /entries/:entry_id/attachments/:id/download
  def download
    data = @attachment.download
    if data
      send_data data,
                filename:    @attachment.filename,
                type:        @attachment.content_type,
                disposition: 'attachment'
    else
      redirect_to @entry, alert: 'Unable to decrypt attachment.'
    end
  end

  private
    def set_entry
      @entry = Entry.find(params.require(:entry_id))
    end

    def set_attachment
      @attachment = @entry.entry_attachments.find(params.require(:id))
    end
end