require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @entry = entries(:one)
    # Stub the unlock check for controller tests - assumes controller actions are the focus
    ApplicationController.define_method(:require_unlocked_journal) {  }
    # Ensure Current gets initialized even if the original before_action is stubbed
    Current.decrypted_private_key = "DUMMY_KEY_FOR_CURRENT"
  end

  test "should get index" do
    get entries_url
    assert_response :success
  end

  test "should get new" do
    get new_entry_url
    assert_response :success
  end

  test "should create entry" do
    assert_difference("Entry.count") do
      post entries_url, params: { entry: { content: @entry.content, entry_date: @entry.entry_date } }
    end

    assert_redirected_to entry_url(Entry.last)
  end

  test "should show entry" do
    get entry_url(@entry)
    assert_response :success
  end

  test "should get edit" do
    get edit_entry_url(@entry)
    assert_response :success
  end

  test "should update entry" do
    patch entry_url(@entry), params: { entry: { content: @entry.content, entry_date: @entry.entry_date } }
    assert_redirected_to entry_url(@entry)
  end

  test "should destroy entry" do
    assert_difference("Entry.count", -1) do
      delete entry_url(@entry)
    end

    assert_redirected_to entries_url
  end
end
