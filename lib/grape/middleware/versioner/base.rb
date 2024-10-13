# frozen_string_literal: true

module Grape
  module Middleware
    module Versioner
      class Base < Grape::Middleware::Base
        DEFAULT_PATTERN = /.*/i.freeze
        DEFAULT_PARAMETER = 'apiver'

        attr_reader :cascade,
                    :mount_path,
                    :parameter_key,
                    :pattern,
                    :prefix,
                    :strict,
                    :vendor,
                    :versions

        def initialize(app, *options)
          super
          # By default those errors contain an `X-Cascade` header set to `pass`, which allows nesting and stacking
          # of routes (see Grape::Router) for more information). To prevent
          # this behavior, and not add the `X-Cascade` header, one can set the `:cascade` option to `false`.
          version_options = @options.fetch(:version_options, {})
          @cascade = version_options.fetch(:cascade, true)
          @mount_path =  @options[:mount_path]
          @parameter_key = version_options.fetch(:parameter, DEFAULT_PARAMETER)
          @pattern = @options.fetch(:pattern, DEFAULT_PATTERN)
          @prefix = @options[:prefix]
          @strict = version_options.fetch(:strict, false)
          @versions = @options[:versions]
          @vendor = version_options[:vendor]
        end

        def error_headers
          cascade ? { Grape::Http::Headers::X_CASCADE => 'pass' } : {}
        end

        def potential_version_match?(potential_version)
          versions.blank? || versions.any? { |v| v.to_s == potential_version }
        end

        def version_not_found!
          throw :error, status: 404, message: '404 API Version Not Found', headers: { Grape::Http::Headers::X_CASCADE => 'pass' }
        end
      end
    end
  end
end
