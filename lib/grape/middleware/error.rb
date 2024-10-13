# frozen_string_literal: true

module Grape
  module Middleware
    class Error < Base
      DEFAULT_STATUS = 500
      DEFAULT_RESCUE_OPTIONS = {
        backtrace: false, # true to display backtrace, true to let Grape handle Grape::Exceptions
        original_exception: false # true to display exception
      }.freeze

      attr_reader :all_rescue_handler,
                  :base_only_rescue_handlers,
                  :default_error_formatter,
                  :default_message,
                  :default_status,
                  :error_formatters,
                  :grape_exceptions_rescue_handler,
                  :rescue_all,
                  :rescue_grape_exceptions,
                  :rescue_handlers,
                  :rescue_options

      def initialize(app, *options)
        super
        self.class.include(@options[:helpers]) if @options[:helpers]
        @all_rescue_handler = @options[:all_rescue_handler]
        @base_only_rescue_handlers = @options[:base_only_rescue_handlers]
        @default_error_formatter = @options[:default_error_formatter]
        @default_message = @options[:default_message]
        @default_status = @options.fetch(:default_status, DEFAULT_STATUS)
        @error_formatters = @options[:error_formatters]
        @format_option = @options.fetch(:format, :txt)
        @grape_exceptions_rescue_handler = @options[:grape_exceptions_rescue_handler]
        @rescue_all = @options.fetch(:rescue_all, false)
        @rescue_grape_exceptions = @options.fetch(:rescue_grape_exceptions, false)
        @rescue_handlers = @options[:rescue_handlers]
        @rescue_options = @options.fetch(:rescue_options, DEFAULT_RESCUE_OPTIONS)
      end

      def call!(env)
        @env = env
        error_response(catch(:error) { return @app.call(@env) })
      rescue Exception => e # rubocop:disable Lint/RescueException
        run_rescue_handler(find_handler(e.class), e, @env[Grape::Env::API_ENDPOINT])
      end

      private

      def rack_response(status, headers, message)
        message = Rack::Utils.escape_html(message) if headers[Rack::CONTENT_TYPE] == Grape::ContentTypes::TEXT_HTML
        Rack::Response.new(Array.wrap(message), Rack::Utils.status_code(status), Grape::Util::Header.new.merge(headers))
      end

      def format_message(message, backtrace, original_exception = nil)
        format = env[Grape::Env::API_FORMAT] || format_option
        formatter = Grape::ErrorFormatter.formatter_for(format, error_formatters, default_error_formatter)
        return formatter.call(message, backtrace, options, env, original_exception) if formatter

        throw :error,
              status: 406,
              message: "The requested format '#{format}' is not supported.",
              backtrace: backtrace,
              original_exception: original_exception
      end

      def find_handler(klass)
        rescue_handler_for_base_only_class(klass) ||
          rescue_handler_for_class_or_its_ancestor(klass) ||
          rescue_handler_for_grape_exception(klass) ||
          rescue_handler_for_any_class(klass) ||
          raise
      end

      def error_response(error = {})
        status = error[:status] || default_status
        message = error[:message] || default_message
        headers = { Rack::CONTENT_TYPE => content_type }.tap do |h|
          h.merge!(error[:headers]) if error[:headers].is_a?(Hash)
        end
        backtrace = error[:backtrace] || error[:original_exception]&.backtrace || []
        original_exception = error.is_a?(Exception) ? error : error[:original_exception] || nil
        rack_response(status, headers, format_message(message, backtrace, original_exception))
      end

      def default_rescue_handler(exception)
        error_response(message: exception.message, backtrace: exception.backtrace, original_exception: exception)
      end

      def rescue_handler_for_base_only_class(klass)
        return unless base_only_rescue_handlers

        error, handler = base_only_rescue_handlers.find { |err, _handler| klass == err }

        return unless error

        handler || method(:default_rescue_handler)
      end

      def rescue_handler_for_class_or_its_ancestor(klass)
        return unless rescue_handlers

        error, handler = rescue_handlers.find { |err, _handler| klass <= err }

        return unless error

        handler || method(:default_rescue_handler)
      end

      def rescue_handler_for_grape_exception(klass)
        return unless klass <= Grape::Exceptions::Base
        return method(:error_response) if klass == Grape::Exceptions::InvalidVersionHeader
        return unless rescue_grape_exceptions || !rescue_all

        grape_exceptions_rescue_handler || method(:error_response)
      end

      def rescue_handler_for_any_class(klass)
        return unless klass <= StandardError
        return unless rescue_all || rescue_grape_exceptions

        all_rescue_handler || method(:default_rescue_handler)
      end

      def run_rescue_handler(handler, error, endpoint)
        if handler.instance_of?(Symbol)
          raise NoMethodError, "undefined method '#{handler}'" unless respond_to?(handler)

          handler = public_method(handler)
        end

        response = catch(:error) do
          handler.arity.zero? ? endpoint.instance_exec(&handler) : endpoint.instance_exec(error, &handler)
        end

        if error?(response)
          error_response(response)
        elsif response.is_a?(Rack::Response)
          response
        else
          run_rescue_handler(method(:default_rescue_handler), Grape::Exceptions::InvalidResponse.new, endpoint)
        end
      end

      def error!(message, status = default_status, headers = {}, backtrace = [], original_exception = nil)
        rack_response(
          status, headers.reverse_merge(Rack::CONTENT_TYPE => content_type),
          format_message(message, backtrace, original_exception)
        )
      end

      def error?(response)
        return false unless response.is_a?(Hash)

        response.key?(:message) && response.key?(:status) && response.key?(:headers)
      end
    end
  end
end
