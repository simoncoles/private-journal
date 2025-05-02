# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- Build/Run: `bin/rails server`, `bin/dev` (using Foreman)
- Test: `bin/rails test` (all), `bin/rails test TEST=test/models/entry_test.rb` (single file)
- System tests: `bin/rails test:system`
- Lint: `bin/rubocop`
- Security: `bin/brakeman`
- Generate encryption keys: `rake encryption:generate_and_seed_keys`

## Code Style
- Ruby/Rails: Follow Rails Omakase style guide (inherited from rubocop-rails-omakase)
- Tests: Use Minitest (standard Rails testing)
- Models: Follow ActiveRecord patterns including validations, callbacks, and relationships
- Encryption: Handle errors gracefully in content/data getters, use OpenSSL for encryption
- Controllers: Use RESTful actions and strong parameters
- Views: Use Rails helpers and Tailwind CSS for styling
- Naming: Follow Rails conventions for all file and class names