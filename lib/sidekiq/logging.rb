require 'time'
require 'logger'

module Sidekiq
  module Logging

    class Pretty < Logger::Formatter
      # Provide a call() method that returns the formatted message.
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601} #{Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end

      def context
        c = Thread.current[:sidekiq_context]
        c ? " #{c}" : ''
      end
    end

    def self.with_context(msg)
      begin
        Thread.current[:sidekiq_context] = msg
        yield
      ensure
        Thread.current[:sidekiq_context] = nil
      end
    end

    def self.initialize_logger(log_target = STDOUT)
      oldlogger = @logger
      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger.formatter = Pretty.new
      oldlogger.close if oldlogger && !$TESTING # don't want to close testing's STDOUT logging
      @logger
    end

    def self.logger
      @logger || initialize_logger
    end

    def self.logger=(log)
      @logger = (log ? log : Logger.new('/dev/null'))
    end

    # This reopens ALL logfiles in the process that have been rotated
    # using logrotate(8) (without copytruncate) or similar tools.
    # A +File+ object is considered for reopening if it is:
    #   1) opened with the O_APPEND and O_WRONLY flags
    #   2) the current open file handle does not match its original open path
    #   3) unbuffered (as far as userspace buffering goes, not O_SYNC)
    # Returns the number of files reopened
    def self.reopen_logs
      to_reopen = []
      nr = 0
      ObjectSpace.each_object(File) { |fp| is_log?(fp) and to_reopen << fp }

      to_reopen.each do |fp|
        orig_st = begin
          fp.stat
        rescue IOError, Errno::EBADF
          next
        end

        begin
          b = File.stat(fp.path)
          next if orig_st.ino == b.ino && orig_st.dev == b.dev
        rescue Errno::ENOENT
        end

        begin
          File.open(fp.path, 'a') { |tmpfp| fp.reopen(tmpfp) }
          fp.sync = true

          nr += 1
        rescue IOError, Errno::EBADF
          # not much we can do...
        end
      end
      nr
    end

    def self.is_log?(fp)
      append_flags = File::WRONLY | File::APPEND

      ! fp.closed? &&
        fp.stat.file? &&
        fp.sync &&
        (fp.fcntl(Fcntl::F_GETFL) & append_flags) == append_flags
    rescue IOError, Errno::EBADF
      false
    end

    def logger
      Sidekiq::Logging.logger
    end
  end
end
