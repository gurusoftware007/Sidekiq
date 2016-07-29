# frozen_string_literal: true

module Sidekiq
  module WebRouter
    GET = 'GET'.freeze
    DELETE = 'DELETE'.freeze
    POST = 'POST'.freeze
    HEAD = 'HEAD'.freeze

    ROUTE_PARAMS = 'rack.route_params'.freeze
    REQUEST_METHOD = 'REQUEST_METHOD'.freeze
    PATH_INFO = 'PATH_INFO'.freeze

    def get(path, &block)
      route(GET, path, &block)
    end

    def post(path, &block)
      route(POST, path, &block)
    end

    def delete(path, &block)
      route(DELETE, path, &block)
    end

    def route(method, path, &block)
      @routes ||= []
      @routes << WebRoute.new(method, path, block)
    end

    def match(env)
      request_method = env[REQUEST_METHOD]
      request_method = GET if request_method == HEAD
      @routes.each do |route|
        if params = route.match(request_method, env[PATH_INFO])
          env[ROUTE_PARAMS] = params
          return WebAction.new(env, route.block)
        end
      end

      nil
    end
  end

  class WebRoute
    attr_accessor :request_method, :pattern, :block, :name

    NAMED_SEGMENTS_PATTERN = /\/([^\/]*):([^:$\/]+)/.freeze

    def initialize(request_method, pattern, block)
      @request_method = request_method
      @pattern = pattern
      @block = block
    end

    def regexp
      @regexp ||= compile
    end

    def compile
      p = if pattern.match(NAMED_SEGMENTS_PATTERN)
        pattern.gsub(NAMED_SEGMENTS_PATTERN, '/\1(?<\2>[^$/]+)')
      else
        pattern
      end

      Regexp.new("\\A#{p}\\Z")
    end

    def match(request_method, path)
      return nil unless request_method == self.request_method

      if path_match = path.match(regexp)
        params = Hash[path_match.names.map(&:to_sym).zip(path_match.captures)]
      end
    end
  end
end
