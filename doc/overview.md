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
    - `created_at`, `updated_at`: Standard Rails timestamps.
  - **Functionality:** Standard CRUD operations (Create, Read, Update, Delete).

- **Encryption:**
  - The `content` of each entry is encrypted using public-key cryptography (RSA).
  - Encryption uses the public key, decryption uses the private key.
  - **Key Storage:** A single RSA public/private key pair is stored in the `encryption_keys` database table. This approach was chosen for easier deployment (especially with Docker) compared to file-based keys.
  - A Rake task (`encryption:generate_and_seed_keys`) exists to generate and store keys if none are present.

- **User Interface:**
  - Standard Rails views (`index`, `show`, `new`, `edit`) are used for managing entries.
  - Views are styled using Tailwind CSS for a modern look and feel.
  - The `show` view renders the entry `content` as HTML using the `redcarpet` gem.
  - Forms use appropriate input types (`datetime_field`, `text_area`).

## 4. Database Schema (`db/schema.rb`)

- **`entries` table:**
  - `entry_date` (datetime)
  - `content` (text, encrypted)
  - `created_at` (datetime)
  - `updated_at` (datetime)

- **`encryption_keys` table:**
  - `public_key` (text)
  - `private_key` (text)
  - `created_at` (datetime)
  - `updated_at` (datetime)

## 5. Key Implementation Details

- **Encryption Logic:** Implemented within the `Entry` model using custom `content=` (encrypt) and `content` (decrypt) methods that interact with the `EncryptionKey` model and OpenSSL.
- **Date Handling:** The `entry_date` was migrated from `date` to `datetime` to store time information. Views and forms have been updated accordingly.
- **Markdown:** A helper method `markdown(text)` in `ApplicationHelper` uses `Redcarpet` to convert Markdown text to HTML.

## 6. Development Environment

- The project includes configuration for Docker/Dev Containers (`.devcontainer/compose.yaml`), suggesting it's set up for containerized development.
