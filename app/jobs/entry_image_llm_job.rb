class EntryImageLlmJob < ApplicationJob
  queue_as :default

  def perform(entry_id, attachment_id)
    entry = Entry.find_by(id: entry_id)
    attachment = Attachment.find_by(id: attachment_id)
    return unless entry && attachment
    return unless attachment.content_type.to_s.start_with?("image/")

    begin
      llm = RubyLLM::Client.new(api_key: ENV["OPENAI_API_KEY"])
      response = llm.chat(
        prompt: build_prompt(entry),
        images: [StringIO.new(attachment.data)]
      )
      entry.update(llm_response: response.to_s)
    rescue StandardError => e
      Rails.logger.error("EntryImageLlmJob failed: #{e.message}")
    end
  end

  private

  def build_prompt(entry)
    "Entry Date: #{entry.entry_date}\nContent: #{entry.content}"
  end
end
