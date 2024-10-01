# frozen_string_literal: true

module Grape
  module DSL
    module Desc
      include Grape::DSL::Settings

      # Add a description to the next namespace or function.
      # @param description [String] descriptive string for this endpoint
      #   or namespace
      # @param options [Hash] other properties you can set to describe the
      #   endpoint or namespace. Optional.
      # @option options :detail [String] additional detail about this endpoint
      # @option options :summary [String] summary for this endpoint
      # @option options :params [Hash] param types and info. normally, you set
      #   these via the `params` dsl method.
      # @option options :entity [Grape::Entity] the entity returned upon a
      #   successful call to this action
      # @option options :http_codes [Array[Array]] possible HTTP codes this
      #   endpoint may return, with their meanings, in a 2d array
      # @option options :named [String] a specific name to help find this route
      # @option options :body_name [String] override the autogenerated body name param
      # @option options :headers [Hash] HTTP headers this method can accept
      # @option options :hidden [Boolean] hide the endpoint or not
      # @option options :deprecated [Boolean] deprecate the endpoint or not
      # @option options :is_array [Boolean] response entity is array or not
      # @option options :nickname [String] nickname of the endpoint
      # @option options :produces [Array[String]] a list of MIME types the endpoint produce
      # @option options :consumes [Array[String]] a list of MIME types the endpoint consume
      # @option options :security [Array[Hash]] a list of security schemes
      # @option options :tags [Array[String]] a list of tags
      # @yield a block yielding an instance context with methods mapping to
      #   each of the above, except that :entity is also aliased as #success
      #   and :http_codes is aliased as #failure.
      #
      # @example
      #
      #     desc 'create a user'
      #     post '/users' do
      #       # ...
      #     end
      #
      #     desc 'find a user' do
      #       detail 'locates the user from the given user ID'
      #       failure [ [404, 'Couldn\'t find the given user' ] ]
      #       success User::Entity
      #     end
      #     get '/user/:id' do
      #       # ...
      #     end
      #
      def desc(description, options = {}, &config_block)
        endpoint_configuration = defined?(configuration) ? configuration : {}
        opts = Grape::Util::ApiDescription.new(description, endpoint_configuration, **options, &config_block).to_h
        namespace_setting :description, opts
        route_setting :description, opts
      end
    end
  end
end
