# frozen_string_literal: true

require "connection_pool"
require "redis"
require "uri"

module Sidekiq
  class RedisConnection
    class << self
      def create(options = {})
        options.keys.each do |key|
          options[key.to_sym] = options.delete(key)
        end

        if !options[:url] && (u = determine_redis_provider)
          options[:url] = u
        end

        size = if options[:size]
          options[:size]
        elsif Sidekiq.server?
          # Give ourselves plenty of connections.  pool is lazy
          # so we won't create them until we need them.
          Sidekiq.options[:concurrency] + 5
        elsif ENV["RAILS_MAX_THREADS"]
          Integer(ENV["RAILS_MAX_THREADS"])
        else
          5
        end

        verify_sizing(size, Sidekiq.options[:concurrency]) if Sidekiq.server?

        pool_timeout = options[:pool_timeout] || 1
        log_info(options)

        ConnectionPool.new(timeout: pool_timeout, size: size) do
          build_client(options)
        end
      end

      private

      # Sidekiq needs a lot of concurrent Redis connections.
      #
      # We need a connection for each Processor.
      # We need a connection for Pro's real-time change listener
      # We need a connection to various features to call Redis every few seconds:
      #   - the process heartbeat.
      #   - enterprise's leader election
      #   - enterprise's cron support
      def verify_sizing(size, concurrency)
        raise ArgumentError, "Your Redis connection pool is too small for Sidekiq to work. Your pool has #{size} connections but must have at least #{concurrency + 2}" if size < (concurrency + 2)
      end

      def build_client(options)
        namespace = options[:namespace]

        client = Redis.new client_opts(options)
        if namespace
          begin
            require "redis/namespace"
            Redis::Namespace.new(namespace, redis: client)
          rescue LoadError
            Sidekiq.logger.error("Your Redis configuration uses the namespace '#{namespace}' but the redis-namespace gem is not included in the Gemfile." \
                                 "Add the gem to your Gemfile to continue using a namespace. Otherwise, remove the namespace parameter.")
            exit(-127)
          end
        else
          client
        end
      end

      def client_opts(options)
        opts = options.dup
        if opts[:namespace]
          opts.delete(:namespace)
        end

        if opts[:network_timeout]
          opts[:timeout] = opts[:network_timeout]
          opts.delete(:network_timeout)
        end

        opts[:driver] ||= Redis::Connection.drivers.last || "ruby"

        # Issue #3303, redis-rb will silently retry an operation.
        # This can lead to duplicate jobs if Sidekiq::Client's LPUSH
        # is performed twice but I believe this is much, much rarer
        # than the reconnect silently fixing a problem; we keep it
        # on by default.
        opts[:reconnect_attempts] ||= 1

        opts
      end

      def log_info(options)
        # Don't log Redis AUTH password
        redacted = "REDACTED"
        scrubbed_options = options.dup
        if scrubbed_options[:url] && (uri = URI.parse(scrubbed_options[:url])) && uri.password
          uri.password = redacted
          scrubbed_options[:url] = uri.to_s
        end
        if scrubbed_options[:password]
          scrubbed_options[:password] = redacted
        end
        scrubbed_options[:sentinels]&.each do |sentinel|
          sentinel[:password] = redacted if sentinel[:password]
        end
        if Sidekiq.server?
          Sidekiq.logger.info("Booting Sidekiq #{Sidekiq::VERSION} with redis options #{scrubbed_options}")
        else
          Sidekiq.logger.debug("#{Sidekiq::NAME} client with redis options #{scrubbed_options}")
        end
      end

      def determine_redis_provider
        # If you have this in your environment:
        # MY_REDIS_URL=redis://hostname.example.com:1238/4
        # then set:
        # REDIS_PROVIDER=MY_REDIS_URL
        # and Sidekiq will find your custom URL variable with no custom
        # initialization code at all.
        #
        p = ENV["REDIS_PROVIDER"]
        if p && p =~ /\:/
          raise <<~EOM
            REDIS_PROVIDER should be set to the name of the variable which contains the Redis URL, not a URL itself.
            Platforms like Heroku will sell addons that publish a *_URL variable.  You need to tell Sidekiq with REDIS_PROVIDER, e.g.:

            REDISTOGO_URL=redis://somehost.example.com:6379/4
            REDIS_PROVIDER=REDISTOGO_URL
          EOM
        end

        ENV[
          p || "REDIS_URL"
        ]
      end
    end
  end
end
