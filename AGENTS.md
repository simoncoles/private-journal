# Agents

## Application Purpose

This is a secure journal. 


## Architecture

The application is written in Ruby on Rails and uses Postgres as a database. 

There are public/private key pairs stored in the  EncryptionKey model. 

New entries are encrypted with a new symmetric key which is then encrypted
with the Public key. 

When the journal is "unlocked" by entering a password, the private key is decrypted
and that allows entries to be decrypted. 

Entries can have attachments which are themselves encrypted. 

## Production Deployment

The application is deployed using Docker Compose and for convenience there's a Justfile with
commands to use. 

You can ignore the Justfile for development purposes. 
