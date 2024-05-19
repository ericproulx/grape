# frozen_string_literal: true

module Grape
  # Represents a path to an endpoint.
  class Path
    attr_reader :raw_path, :namespace, :settings

    def initialize(raw_path, namespace, settings)
      @raw_path = raw_path
      @namespace = namespace
      @settings = settings
    end

    def mount_path
      settings[:mount_path]
    end

    def root_prefix
      settings[:root_prefix]
    end

    def uses_specific_format?
      return false unless settings.key?(:format) && settings.key?(:content_types)

      settings[:format] && Array(settings[:content_types]).size == 1
    end

    def uses_path_versioning?
      return false unless settings.key?(:version) && settings[:version_options]&.key?(:using)

      settings[:version] && settings[:version_options][:using] == :path
    end

    def namespace?
      namespace&.match?(/^\S/) && not_slash?(namespace)
    end

    def path?
      raw_path&.match?(/^\S/) && not_slash?(raw_path)
    end

    def suffix
      if uses_specific_format?
        "(.#{settings[:format]})"
      elsif !uses_path_versioning? || (namespace? || path?)
        '(.:format)'
      else
        '(/.:format)'
      end
    end

    def path
      PartsCache[parts]
    end

    def path_with_suffix
      "#{path}#{suffix}"
    end

    def to_s
      path_with_suffix
    end

    private

    class PartsCache < Grape::Util::Cache
      def initialize
        @cache = Hash.new do |h, parts|
          h[parts] = Grape::Router.normalize_path(parts.join('/'))
        end
      end
    end

    def parts
      [].tap do |parts|
        parts << mount_path
        parts << root_prefix if root_prefix.present?
        parts << ':version' if uses_path_versioning?
        parts << namespace
        parts << raw_path
      end.keep_if { |p| not_slash?(p) }
    end

    def not_slash?(value)
      value != '/'
    end
  end
end
