# frozen_string_literal: true

module Spec
  module Support
    class EndpointFaker
      class FakerAPI < Grape::API
        get('/')
      end

      def initialize(app, endpoint = FakerAPI.endpoints.first)
        @app = app
        @endpoint = endpoint
      end

      def call(env)
        @endpoint.instance_exec do
          @request = Grape::Request.new(env.dup)
        end

        @app.call(env.merge(Grape::Env::API_ENDPOINT => @endpoint))
      end
    end
  end
end
