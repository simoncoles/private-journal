# Generating Encryption Keys

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

