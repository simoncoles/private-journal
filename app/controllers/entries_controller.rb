class EntriesController < ApplicationController
  # Add this line to enforce unlock for all entry actions
  before_action :require_unlocked_journal, except: [ :new, :create ]
  # Skip CSRF protection for create action
  skip_before_action :verify_authenticity_token, only: [ :create ]
  before_action :set_entry, only: [ :show, :edit, :update, :destroy ]

  # GET /entries or /entries.json
  def index
    @entries = Entry.all
  end

  # GET /entries/1 or /entries/1.json
  def show
  end

  # GET /entries/new
  def new
    # Set the default entry_date to the current time
    @entry = Entry.new(entry_date: Time.current)
  end

  # GET /entries/1/edit
  def edit
  end

  # POST /entries or /entries.json
  def create
    @entry = Entry.new(entry_params)

    # Log params for debugging
    Rails.logger.debug "Entry creation params: #{params.inspect}"

    attachments_param = params.dig(:entry, :attachments)

    if params[:ask].present?
      begin
        response_text = ask_llm(@entry.content, attachments_param)
        @entry.content = "## Question\n#{@entry.content}\n\n## Response\n#{response_text}"
      rescue => e
        Rails.logger.error "LLM request failed: #{e.message}"
        @entry.errors.add(:base, "LLM request failed: #{e.message}")
      end
    end

    respond_to do |format|
      if @entry.errors.empty? && @entry.save
        create_attachments(@entry, attachments_param) if attachments_param

        format.html { redirect_to @entry, notice: "Entry was successfully created." }
        format.json { render :show, status: :created, location: @entry }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /entries/1 or /entries/1.json
  def update
    # Log params for debugging
    Rails.logger.debug "Entry update params: #{params.inspect}"

    respond_to do |format|
      if @entry.update(entry_params)
        # Handle file attachments if any
        if params[:entry] && params[:entry][:attachments]
          Rails.logger.debug "Processing attachments from params: #{params[:entry][:attachments].inspect}"
          create_attachments(@entry, params[:entry][:attachments])
        end

        format.html { redirect_to @entry, notice: "Entry was successfully updated." }
        format.json { render :show, status: :ok, location: @entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /entries/1 or /entries/1.json
  def destroy
    @entry.destroy!

    respond_to do |format|
      format.html { redirect_to entries_path, status: :see_other, notice: "Entry was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = Entry.find(params.require(:id))
    end

    # Only allow a list of trusted parameters through.
    def entry_params
      params.require(:entry).permit(:entry_date, :content, :category)
    end

    # Send the user's input and optional image to the configured LLM
    def ask_llm(text, attachment_files)
      chat = RubyLLM.chat

      files = attachment_files.is_a?(Array) ? attachment_files : Array(attachment_files)
      image_file = files.find { |f| f.respond_to?(:content_type) && f.content_type.to_s.start_with?("image/") }

      if image_file
        chat.ask(text, with: { image: image_file.tempfile.path }).content
      else
        chat.ask(text).content
      end
    end

    # Handle creating attachments for an entry
    def create_attachments(entry, attachment_files)
      return unless attachment_files.present?

      # Handle different parameter formats - it could be an array or another structure
      files_to_process = attachment_files.is_a?(Array) ? attachment_files : [ attachment_files ]

      files_to_process.each do |file|
        next if file.blank?

        # Debug logging to check what's being received
        Rails.logger.debug "Processing attachment: #{file.original_filename}" if file.respond_to?(:original_filename)

        attachment = entry.attachments.build
        attachment.file = file

        # Debug logging for saved attachment - avoid inspecting the full object which triggers decryption
        if attachment.save
          Rails.logger.debug "Attachment saved successfully with ID: #{attachment.id}"
        else
          Rails.logger.error "Attachment save failed: #{attachment.errors.full_messages.join(', ')}"
        end
      end
    end
end
