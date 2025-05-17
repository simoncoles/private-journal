# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :active_record_store,
  key: "_private_journal_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 12.hours
