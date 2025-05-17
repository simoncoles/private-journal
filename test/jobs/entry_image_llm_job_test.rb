require "test_helper"

class EntryImageLlmJobTest < ActiveJob::TestCase
  setup do
    rsa_key = OpenSSL::PKey::RSA.new(2048)
    @private_key = rsa_key.to_pem
    @public_key = rsa_key.public_key.to_pem

    EncryptionKey.destroy_all
    Entry.destroy_all

    @encryption_key = EncryptionKey.create!(public_key: @public_key, private_key: @private_key)
    @entry = Entry.create!(entry_date: Time.current, content: "Test entry", encryption_key: @encryption_key)

    Current.decrypted_private_key = @private_key
  end

  teardown do
    Current.reset
    Entry.destroy_all
    EncryptionKey.destroy_all
  end

  test "stores LLM response on entry" do
    file = StringIO.new("img")
    def file.original_filename; "test.png"; end
    def file.content_type; "image/png"; end

    attachment = Attachment.new(entry: @entry, encryption_key: @encryption_key)
    attachment.file = file
    attachment.save!

    RubyLLM = Module.new unless defined?(RubyLLM)
    RubyLLM.const_set(:Client, Class.new do
      def initialize(api_key:); end
      def chat(prompt:, images:); "analysis result"; end
    end)

    EntryImageLlmJob.perform_now(@entry.id, attachment.id)
    assert_equal "analysis result", @entry.reload.llm_response

    RubyLLM.send(:remove_const, :Client)
  end
end
