# frozen_string_literal: true

module Grape
  module Middleware
    class Base
      include Helpers
      include Grape::DSL::Headers

      attr_reader :app, :env, :options, :format_option, :content_types_option

      DEFAULT_OPTIONS = {}.freeze

      # @param [Rack Application] app The standard argument for a Rack middleware.
      # @param [Hash] options A hash of options, simply stored for use by subclasses.
      def initialize(app, *options)
        @app = app
        @options = options.any? ? options.shift : DEFAULT_OPTIONS
        @format_option = @options[:format]
        @content_types_option = @options[:content_types]
        @app_response = nil
      end

      def call(env)
        dup.call!(env).to_a
      end

      def call!(env)
        @env = env
        before
        begin
          @app_response = @app.call(@env)
        ensure
          begin
            after_response = after
          rescue StandardError => e
            warn "caught error of type #{e.class} in after callback inside #{self.class.name} : #{e.message}"
            raise e
          end
        end

        response = after_response || @app_response
        merge_headers response
        response
      end

      # @abstract
      # Called before the application is called in the middleware lifecycle.
      def before; end

      # @abstract
      # Called after the application is called in the middleware lifecycle.
      # @return [Response, nil] a Rack SPEC response or nil to call the application afterwards.
      def after; end

      def response
        return @app_response if @app_response.is_a?(Rack::Response)

        @app_response = Rack::Response.new(@app_response[2], @app_response[0], @app_response[1])
      end

      def content_types
        @content_types ||= Grape::ContentTypes.content_types_for(content_types_option)
      end

      def mime_types
        @mime_types ||= Grape::ContentTypes.mime_types_for(content_types)
      end

      def content_type_for(format)
        content_types_indifferent_access[format]
      end

      def content_type?(format)
        content_types_indifferent_access.key?(format)
      end

      def content_type
        content_type_for(env[Grape::Env::API_FORMAT] || format_option) || Grape::ContentTypes::TEXT_HTML
      end

      private

      def merge_headers(response)
        return unless headers.is_a?(Hash)

        case response
        when Rack::Response then response.headers.merge!(headers)
        when Array          then response[1].merge!(headers)
        end
      end

      def content_types_indifferent_access
        @content_types_indifferent_access ||= content_types.with_indifferent_access
      end
    end
  end
end
