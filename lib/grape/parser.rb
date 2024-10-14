# frozen_string_literal: true

module Grape
  module Parser
    DEFAULTS_FORMATS = %i(json jsonapi xml).freeze
    class << self
      def parser_for(format, parsers = nil)
        parsers&.key?(format) ? parsers[format] : try_defaults(format)
      end

      private

      def try_defaults(api_format)
        return if DEFAULTS_FORMATS.exclude?(api_format)

        DefaultParserCache[api_format]
      end

      class DefaultParserCache < Grape::Util::Cache
        def initialize
          super
          @cache = Hash.new do |h, api_format|
            h[api_format] = Grape::Parser.const_get(:"#{api_format.to_s.camelize}")
          end
        end
      end
    end
  end
end
