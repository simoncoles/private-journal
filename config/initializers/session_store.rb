# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  key: "_private_journal_session",
  secure: true,
  httponly: true,
  same_site: :lax
