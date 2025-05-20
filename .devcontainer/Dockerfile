# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install Just which we are using as a command runner
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin

