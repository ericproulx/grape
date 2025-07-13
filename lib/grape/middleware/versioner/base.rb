# frozen_string_literal: true

module Grape
  module Middleware
    module Versioner
      class Base < Grape::Middleware::Base
        DEFAULT_OPTIONS = {
          pattern: /.*/i,
          prefix: nil,
          mount_path: nil,
          version_options: {
            strict: false,
            cascade: true,
            parameter: 'apiver',
            vendor: nil
          }.freeze
        }.freeze

        CASCADE_PASS_HEADER = { 'X-Cascade' => 'pass' }.freeze

        DEFAULT_OPTIONS.each_key do |key|
          define_method key do
            options[key]
          end
        end

        DEFAULT_OPTIONS[:version_options].each_key do |key|
          define_method key do
            options[:version_options][key]
          end
        end

        def self.inherited(klass)
          super
          Versioner.register(klass)
        end

        attr_reader :error_headers, :versions

        def initialize(app, **options)
          super
          @error_headers = cascade ? CASCADE_PASS_HEADER : {}
          @versions = options[:versions]&.map(&:to_s) # making sure versions are strings to easy potential match
        end

        def potential_version_match?(potential_version)
          versions.blank? || versions.include?(potential_version)
        end

        def version_not_found!
          throw :error, status: 404, message: '404 API Version Not Found', headers: CASCADE_PASS_HEADER
        end
      end
    end
  end
end
