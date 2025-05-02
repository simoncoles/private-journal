# Application Overview: Private Journal

This document provides an overview of the Private Journal application.

## 1. Purpose

The application serves as a secure, private digital journal. Users can create, view, edit, and delete journal entries.

## 2. Technology Stack

- **Framework:** Ruby on Rails (v8.x)
- **Language:** Ruby
- **Database:** Default Rails setup (likely SQLite in development), managed via Active Record.
- **Frontend Styling:** Tailwind CSS
- **Encryption:** OpenSSL (Ruby library)
- **Markdown Rendering:** Redcarpet gem
- **Web Server:** Puma

## 3. Core Features

- **Journal Entries (`Entry` model):**
  - **Attributes:**
    - `entry_date`: `datetime` (Defaults to the current time for new entries).
    - `content`: `text` (Stores journal content, intended to be Markdown formatted).
    - `category`: `string` (Defaults to 'Diary', must be either 'Diary' or 'ChatGPT'. Added in migration `YYYYMMDDHHMMSS_add_category_to_entries.rb` - *replace timestamp if known*).
    - `created_at`, `updated_at`: Standard Rails timestamps.
  - **Functionality:** Standard CRUD operations (Create, Read, Update, Delete).
  - **Validation:** `category` must be one of `Entry::CATEGORIES` ('Diary', 'ChatGPT').
  - **Relationships:** Has many `attachments` (added for file storage)

- **Attachments (`Attachment` model):**
  - **Attributes:**
    - `name`: `string` (Original filename of the uploaded file)
    - `content_type`: `string` (MIME type of the uploaded file)
    - `data`: `binary` (Encrypted file data)
    - `entry_id`: `integer` (Foreign key to the associated entry)
    - `created_at`, `updated_at`: Standard Rails timestamps
  - **Functionality:** 
    - Storage of encrypted files associated with entries
    - Secure download of decrypted files
  - **Validation:** Requires `name` and `content_type`
  - **Relationships:** Belongs to an `entry`

- **Encryption:**
  - The `content` of each entry is encrypted using public-key cryptography (RSA).
  - Attachment `data` is also encrypted using the same public-key cryptography (RSA).
  - Encryption uses the public key, decryption uses the private key.

- **User Interface:**
  - Standard Rails views (`index`, `show`, `new`, `edit`) are used for managing entries.
  - Views are styled using Tailwind CSS for a modern look and feel.
  - The `show` view renders the entry `content` as HTML using the `redcarpet` gem.
  - Forms use appropriate input types (`datetime_field`, `text_area`).
  - File upload fields allow users to attach multiple files to entries.
  - The `show` view displays attachments with download links.

## 4. Database Schema (`db/schema.rb`)

- **`entries` table:**
  - `entry_date` (datetime)
  - `content` (text, encrypted)
  - `category` (string, not null, default: 'Diary')
  - `created_at` (datetime)
  - `updated_at` (datetime)
  - `encryption_key_id` (integer, not null, foreign key)

- **`attachments` table:**
  - `name` (string)
  - `content_type` (string)
  - `data` (binary, encrypted)
  - `entry_id` (integer, not null, foreign key)
  - `created_at` (datetime)
  - `updated_at` (datetime)

## 5. Key Implementation Details

- **Encryption Logic:** 
  - Implemented within the `Entry` model using custom `content=` (encrypt) and `content` (decrypt) methods.
  - Similarly implemented in the `Attachment` model using custom `data=` (encrypt) and `data` (decrypt) methods.
  - Both models access the keys stored in `Rails.application.config.encryption_keys` and use OpenSSL.
  - The setters raise a `RuntimeError` if the public key is unavailable or encryption fails.
  - The getters handle decryption errors (missing private key, corrupted data, invalid Base64) by logging the error and returning specific placeholder strings like `"[Content/Data Encrypted - Key Unavailable]"` or `"[Content/Data Decryption Failed]"`.

- **Date Handling:** The `entry_date` was migrated from `date` to `datetime` to store time information. Views and forms have been updated accordingly.
- **Markdown:** A helper method `markdown(text)` in `ApplicationHelper` uses `Redcarpet` to convert Markdown text to HTML.

## 6. Development Environment

- The project includes configuration for Docker/Dev Containers (`.devcontainer/compose.yaml`), suggesting it's set up for containerized development.

## 7. Testing

- Unit tests for the `Entry` model are located in `test/models/entry_test.rb`.
- These tests cover:
  - `category` validations.
  - Correct encryption and decryption of the `content` attribute.
  - Handling of blank/nil content.
  - Error scenarios during encryption (missing public key).
  - Error scenarios during decryption (missing private key, corrupted data, invalid Base64 encoding).
