# Be sure to restart your server when you modify this file.
# Unfilter encryption_key_id attribute from ActiveRecord inspection
# This allows encryption_key_id to appear in console output
Rails.application.config.after_initialize do
  # Get the current filter attributes from ActiveRecord
  filtered_attributes = ActiveRecord::Base.filter_attributes.dup

  # Remove any filter pattern that would catch encryption_key_id
  filtered_attributes.reject! { |pattern|
    pattern.is_a?(Regexp) && "encryption_key_id" =~ pattern ||
    pattern.is_a?(String) && "encryption_key_id".include?(pattern)
  }

  # Reset the filter_attributes with our modified list
  ActiveRecord::Base.filter_attributes = filtered_attributes
end
