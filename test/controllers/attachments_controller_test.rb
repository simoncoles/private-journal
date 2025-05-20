require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attachment = attachments(:one)
    @entry = entries(:one)

    # Save original data method so it can be restored after stubbing
    @original_data_method = Attachment.instance_method(:data)

    # Stub the unlock check for controller tests - assumes controller actions are the focus
    ApplicationController.define_method(:require_unlocked_journal) {  }
    # Ensure Current gets initialized even if the original before_action is stubbed
    Current.decrypted_private_key = "DUMMY_KEY_FOR_CURRENT"
  end

  teardown do
    # Restore original data method in case a test stubbed it
    Attachment.define_method(:data, @original_data_method)
  end

  test "should download attachment" do
    # Stub the data method to return predictable test content
    Attachment.define_method(:data) { "Test file content for download" }

    get download_attachment_url(@attachment)
    assert_response :success

    # Check that the content was sent with proper headers
    assert_equal "Test file content for download", response.body
    assert_equal @attachment.content_type, response.content_type
    assert_equal "attachment", response.headers["Content-Disposition"].split(";").first
    assert_includes response.headers["Content-Disposition"], @attachment.name

    # Restore original method
    Attachment.remove_method(:data)
  end

  test "should handle attachment download error" do
    # Stub the data method to return an error
    Attachment.define_method(:data) { "[Data Encrypted - Key Unavailable]" }

    get download_attachment_url(@attachment)
    assert_redirected_to entry_url(@attachment.entry)
    assert_not_nil flash[:alert]
    assert_includes flash[:alert], "Unable to download"

    # Restore original method
    Attachment.remove_method(:data)
  end

  test "should destroy attachment" do
    assert_difference("Attachment.count", -1) do
      delete attachment_url(@attachment)
    end

    assert_redirected_to edit_entry_url(@attachment.entry)
    assert_equal "Attachment was successfully removed.", flash[:notice]
  end

  test "should handle destroy with turbo stream" do
    assert_difference("Attachment.count", -1) do
      delete attachment_url(@attachment), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match %r{^text/vnd\.turbo-stream\.html}, response.content_type
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "remove"
    assert_includes response.body, "attachment_#{@attachment.id}"
  end
end
