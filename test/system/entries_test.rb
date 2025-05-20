require "application_system_test_case"

class EntriesTest < ApplicationSystemTestCase
  setup do
    @entry = entries(:one)
    # Create a real encryption key and unlock the journal for system tests
    @test_passphrase = "test-pass"
    encryption_key = EncryptionKey.generate_and_save(@test_passphrase)

    # Existing fixture entries reference placeholder keys which cause
    # encryption to fail. Reassign them to the real key created above.
    Entry.update_all(encryption_key_id: encryption_key.id)

    visit new_session_path
    fill_in "Password", with: @test_passphrase
    click_on "Unlock"
  end

  test "visiting the index" do
    visit entries_url
    assert_selector "h1", text: "Entries"
  end

  test "should create entry" do
    visit entries_url
    click_on "New Entry", match: :first

    # Use specific values that will pass validations
    fill_in "Content", with: "Test content for a new entry"
    fill_in "Entry date", with: DateTime.current.strftime("%Y-%m-%dT%H:%M")
    select "Diary", from: "Category"

    click_on "Create Entry"

    assert_text "Entry was successfully created"
    click_on "Back"
  end

  test "should update Entry" do
    visit entry_url(@entry)
    click_on "Edit this entry", match: :first

    fill_in "Content", with: @entry.content
    fill_in "Entry date", with: @entry.entry_date.strftime("%Y-%m-%dT%H:%M")
    click_on "Update Entry"

    assert_text "Entry was successfully updated"
    click_on "Back"
  end

  test "should destroy Entry" do
    visit entry_url(@entry)
    accept_confirm { click_on "Destroy this entry", match: :first }

    assert_text "Entry was successfully destroyed"
  end
end
