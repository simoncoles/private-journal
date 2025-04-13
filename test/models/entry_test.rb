# == Schema Information
#
# Table name: entries
#
#  id         :integer          not null, primary key
#  category   :string           default("Diary"), not null
#  content    :text
#  entry_date :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class EntryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
