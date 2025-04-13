require "openssl"
require "base64"

# This initializer could be used to load a default key pair
# from environment variables or a configuration file if needed.
# For example:
#
# if Rails.env.production?
#   PRIVATE_KEY_PEM = ENV["PRIVATE_KEY_PEM"]
#   PUBLIC_KEY_PEM = ENV["PUBLIC_KEY_PEM"]
#   unless PRIVATE_KEY_PEM && PUBLIC_KEY_PEM
#     raise "Encryption keys are not set in the environment variables."
#   end
# else
  # Load development keys or generate them if they don't exist
# end
