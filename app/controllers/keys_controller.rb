require "zip"
require "stringio"

class KeysController < ApplicationController
  def index
    # This action just renders the index view
  end

  def download
    encryption_key = EncryptionKey.first

    if encryption_key.nil?
      redirect_to keys_index_path, alert: "No encryption keys found in the database. Please run 'rake encryption:generate_and_seed_keys'."
      return
    end

    # Create zip in memory
    stringio = Zip::OutputStream.write_buffer do |zio|
      zio.put_next_entry("public_key.pem")
      zio.write encryption_key.public_key

      zio.put_next_entry("private_key.pem")
      zio.write encryption_key.private_key
    end

    stringio.rewind # Reset buffer position
    zip_data = stringio.read

    send_data zip_data,
              type: "application/zip",
              disposition: "attachment",
              filename: "private_journal_keys_#{Time.current.strftime("%Y%m%d%H%M%S")}.zip"
  end
end
