# == Schema Information
#
# Table name: encryption_keys
#
#  id          :integer          not null, primary key
#  private_key :text
#  public_key  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class EncryptionKey < ApplicationRecord
end
