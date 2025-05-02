# Be sure to restart your server when you modify this file.

# Configure secure headers for the application
Rails.application.configure do
  # Enable X-Content-Type-Options header
  config.action_dispatch.default_headers["X-Content-Type-Options"] = "nosniff"
  
  # Add X-XSS-Protection header
  config.action_dispatch.default_headers["X-XSS-Protection"] = "1; mode=block"
  
  # Add secure cache control headers
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000',
    'Vary' => 'Accept-Encoding'
  }
end
