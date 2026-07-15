# SourceBase subclasses ActiveRecord::Base (not ApplicationRecord) on purpose:
# it establishes a separate connection pool to the legacy Freshchat Postgres,
# and must not share the Chatwoot main-DB connection that ApplicationRecord uses.
class Freshchat::SourceBase < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
  self.abstract_class = true

  class MissingCredentialsError < StandardError; end

  def self.connect!
    return if @connected

    missing = %w[FRESHCHAT_DB_HOST FRESHCHAT_DB_NAME FRESHCHAT_DB_USER FRESHCHAT_DB_PASSWORD].reject { |k| ENV[k].present? }
    raise MissingCredentialsError, "Missing env vars: #{missing.join(', ')}" if missing.any?

    establish_connection(
      adapter: 'postgresql',
      host: ENV.fetch('FRESHCHAT_DB_HOST'),
      port: ENV.fetch('FRESHCHAT_DB_PORT', '5432').to_i,
      database: ENV.fetch('FRESHCHAT_DB_NAME'),
      username: ENV.fetch('FRESHCHAT_DB_USER'),
      password: ENV.fetch('FRESHCHAT_DB_PASSWORD'),
      pool: 5,
      connect_timeout: 10,
      variables: { statement_timeout: 0 }
    )

    @connected = true
  end
end
