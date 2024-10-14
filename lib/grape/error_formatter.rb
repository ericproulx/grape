# frozen_string_literal: true

module Grape
  module ErrorFormatter
    DEFAULTS_FORMATS = %i[json jsonapi serializable_hash txt xml].freeze

    class << self
      def formatter_for(format, error_formatters = nil, default_error_formatter = nil)
        select_formatter(error_formatters, format) || default_error_formatter || DefaultFormatterCache[:txt]
      end

      def select_formatter(error_formatters, format)
        error_formatters&.key?(format) ? error_formatters[format] : try_defaults(format)
      end

      private

      def try_defaults(api_format)
        return if DEFAULTS_FORMATS.exclude?(api_format)

        DefaultFormatterCache[api_format]
      end

      class DefaultFormatterCache < Grape::Util::Cache
        def initialize
          super
          @cache = Hash.new do |h, api_format|
            h[api_format] = Grape::ErrorFormatter.const_get(:"#{api_format.to_s.camelize}")
          end
        end
      end
    end
  end
end
