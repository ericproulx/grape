# frozen_string_literal: true

module Grape
  class Router
    class Route
      extend Forwardable

      attr_reader :app, :pattern, :request_method, :capture_index

      def_delegators :pattern, :path, :origin
      # params must be handled in this class to avoid method redefined warning
      delegate Grape::Router::AttributeTranslator::ROUTE_ATTRIBUTES - [:params] => :@attributes

      def initialize(method, pattern, **options)
        @request_method = upcase_method(method)
        @pattern = Grape::Router::Pattern.new(pattern, **options)
        @attributes = Grape::Router::AttributeTranslator.new(**options)
      end

      def options
        @attributes.to_h
      end

      def exec(env)
        @app.call(env)
      end

      def apply(app)
        @app = app
        self
      end

      def match?(input)
        return false if input.blank?

        @attributes.forward_match ? input.start_with?(origin) : pattern.match?(input)
      end

      def params(input = nil)
        return params_without_input if input.blank?

        parsed = pattern.params(input)
        return {} unless parsed

        parsed.compact.symbolize_keys
      end

      def to_regexp(index)
        @capture_index = "_#{index}"
        Regexp.new("(?<#{@capture_index}>#{pattern.to_regexp})")
      end

      private

      def params_without_input
        pattern.captures_default.merge(@attributes.params)
      end

      def upcase_method(method)
        method_s = method.to_s
        Grape::Http::Headers.find_supported_method(method_s) || method_s.upcase
      end
    end
  end
end
