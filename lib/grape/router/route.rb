# frozen_string_literal: true

module Grape
  class Router
    class Route
      extend Forwardable

      attr_reader :app, :pattern, :options
      attr_accessor :index

      def_delegators :pattern, :path, :origin
      # params must be handled in this class to avoid method redefined warning
      delegate Grape::Router::AttributeTranslator::ROUTE_ATTRIBUTES - [:params] => :options

      def initialize(method, pattern, **options)
        @pattern = Grape::Router::Pattern.new(pattern, **options)
        @options = Grape::Router::AttributeTranslator.new(**options, request_method: upcase_method(method))
      end

      alias attributes options

      def exec(env)
        @app.call(env)
      end

      def apply(app)
        @app = app
        self
      end

      def match?(input)
        return false if input.blank?

        attributes.forward_match ? input.start_with?(pattern.origin) : pattern.match?(input)
      end

      def params(input = nil)
        return params_without_input if input.blank?

        parsed = pattern.params(input)
        return {} unless parsed

        parsed.compact.symbolize_keys
      end

      private

      def params_without_input
        pattern.captures_default.merge(attributes.params)
      end

      def upcase_method(method)
        method_s = method.to_s
        Grape::Http::Headers.find_supported_method(method_s) || method_s.upcase
      end
    end
  end
end
