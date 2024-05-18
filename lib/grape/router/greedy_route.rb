# frozen_string_literal: true

# Act like a Grape::Router::Route but for greedy_match
# see @neutral_map

module Grape
  class Router
    class GreedyRoute
      extend Forwardable

      attr_reader :index, :pattern, :attributes

      # params must be handled in this class to avoid method redefined warning
      delegate Grape::Router::AttributeTranslator::ROUTE_ATTRIBUTES - [:params] => :@attributes

      def initialize(index:, pattern:, **options)
        @index = index
        @pattern = pattern
        @attributes = Grape::Router::AttributeTranslator.new(**options)
      end

      alias options attributes

      # Grape::Router:Route defines params as a function
      def params(_input = nil)
        @attributes.params || {}
      end
    end
  end
end
