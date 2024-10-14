# frozen_string_literal: true

module Grape
  module Formatter
    DEFAULTS_FORMATS = %i[json jsonapi serializable_hash txt xml].freeze
    DEFAULT_LAMBDA_FORMATTER = ->(obj, _env) { obj }

    class << self
      def formatter_for(api_format, formatters)
        select_formatter(formatters, api_format) || DEFAULT_LAMBDA_FORMATTER
      end

      def select_formatter(formatters, api_format)
        formatters&.key?(api_format) ? formatters[api_format] : try_defaults(api_format)
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
            h[api_format] = Grape::Formatter.const_get(:"#{api_format.to_s.camelize}")
          end
        end
      end
    end
  end
end
