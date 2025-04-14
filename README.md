# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

Key generation

```bash
openssl genpkey -algorithm RSA -out config/keys/private.pem -pkeyopt rsa_keygen_bits:4096 && openssl rsa -pubout -in config/keys/private.pem -out config/keys/public.pem
```

## Generating Encryption Keys

To generate a new encryption key pair (public key and encrypted private key):

1.  Open the Rails console:
    ```bash
    rails c
    ```
2.  Run the following command, replacing `'your_secret_passphrase'` with a strong passphrase you will remember. This passphrase is required to unlock the journal later.
    ```ruby
    EncryptionKey.generate_and_save('your_secret_passphrase')
    ```

This will create a new record in the `encryption_keys` table. The public key is stored directly, and the private key is encrypted using the provided passphrase before being stored.

**Important:** Keep your passphrase secure. If you lose it, you will not be able to decrypt your journal entries associated with this key pair.