# frozen_string_literal: true

require 'shared/versioning_examples'

describe Grape::API do
  subject(:a_remounted_api) { Class.new(described_class) }

  let(:root_api) { Class.new(described_class) }

  let(:app) { root_api }

  describe 'remounting an API' do
    context 'with a defined route' do
      before do
        a_remounted_api.get '/votes' do
          '10 votes'
        end
      end

      context 'when mounting one instance' do
        before do
          root_api.mount a_remounted_api
        end

        it 'can access the endpoint' do
          get '/votes'
          expect(last_response.body).to eql '10 votes'
        end
      end

      context 'when mounting twice' do
        before do
          root_api.mount a_remounted_api => '/posts'
          root_api.mount a_remounted_api => '/comments'
        end

        it 'can access the votes in both places' do
          get '/posts/votes'
          expect(last_response.body).to eql '10 votes'
          get '/comments/votes'
          expect(last_response.body).to eql '10 votes'
        end
      end

      context 'when mounting on namespace' do
        before do
          stub_const('StaticRefToAPI', a_remounted_api)
          root_api.namespace 'posts' do
            mount StaticRefToAPI
          end

          root_api.namespace 'comments' do
            mount StaticRefToAPI
          end
        end

        it 'can access the votes in both places' do
          get '/posts/votes'
          expect(last_response.body).to eql '10 votes'
          get '/comments/votes'
          expect(last_response.body).to eql '10 votes'
        end
      end
    end

    describe 'with dynamic configuration' do
      context 'when mounting an endpoint conditional on a configuration' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            get 'always' do
              'success'
            end

            given configuration[:mount_sometimes] do
              get 'sometimes' do
                'sometimes'
              end
            end
          end
        end

        it 'mounts the endpoints only when configured to do so' do
          root_api.mount({ a_remounted_api => 'with_conditional' }, with: { mount_sometimes: true })
          root_api.mount({ a_remounted_api => 'without_conditional' }, with: { mount_sometimes: false })

          get '/with_conditional/always'
          expect(last_response.body).to eq 'success'

          get '/with_conditional/sometimes'
          expect(last_response.body).to eq 'sometimes'

          get '/without_conditional/always'
          expect(last_response.body).to eq 'success'

          get '/without_conditional/sometimes'
          expect(last_response).to be_not_found
        end
      end

      context 'when using an expression derived from a configuration' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            get(mounted { "api_name_#{configuration[:api_name]}" }) do
              'success'
            end
          end
        end

        before do
          root_api.mount a_remounted_api, with: {
            api_name: 'a_name'
          }
        end

        it 'mounts the endpoint with the name' do
          get 'api_name_a_name'
          expect(last_response.body).to eq 'success'
        end

        it 'does not mount the endpoint with a null name' do
          get 'api_name_'
          expect(last_response.body).not_to eq 'success'
        end

        context 'when the expression lives in a namespace' do
          subject(:a_remounted_api) do
            Class.new(described_class) do
              namespace :base do
                get(mounted { "api_name_#{configuration[:api_name]}" }) do
                  'success'
                end
              end
            end
          end

          it 'mounts the endpoint with the name' do
            get 'base/api_name_a_name'
            expect(last_response.body).to eq 'success'
          end

          it 'does not mount the endpoint with a null name' do
            get 'base/api_name_'
            expect(last_response.body).not_to eq 'success'
          end
        end
      end

      context 'when the params are configured via a configuration' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            params do
              requires configuration[:required_attr_name], type: String
            end

            get(mounted { configuration[:endpoint] }) do
              status 200
            end
          end
        end

        context 'when the configured param is my_attr' do
          it 'requires the configured params' do
            root_api.mount a_remounted_api, with: {
              required_attr_name: 'my_attr',
              endpoint: 'test'
            }
            get 'test?another_attr=1'
            expect(last_response).to be_bad_request
            get 'test?my_attr=1'
            expect(last_response).to be_successful

            root_api.mount a_remounted_api, with: {
              required_attr_name: 'another_attr',
              endpoint: 'test_b'
            }
            get 'test_b?another_attr=1'
            expect(last_response).to be_successful
            get 'test_b?my_attr=1'
            expect(last_response).to be_bad_request
          end
        end
      end

      context 'when executing a standard block within a `mounted` block with all dynamic params' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            mounted do
              desc configuration[:description] do
                headers configuration[:headers]
              end
              get configuration[:endpoint] do
                configuration[:response]
              end
            end
          end
        end

        let(:api_endpoint) { 'custom_endpoint' }
        let(:api_response) { 'custom response' }
        let(:endpoint_description) { 'this is a custom API' }
        let(:headers) do
          {
            'XAuthToken' => {
              'description' => 'Validates your identity',
              'required' => true
            }
          }
        end

        it 'mounts the API and obtains the description and headers definition' do
          root_api.mount a_remounted_api, with: {
            description: endpoint_description,
            headers: headers,
            endpoint: api_endpoint,
            response: api_response
          }
          get api_endpoint
          expect(last_response.body).to eq api_response
          expect(a_remounted_api.instances.last.endpoints.first.options[:route_options][:description])
            .to eq endpoint_description
          expect(a_remounted_api.instances.last.endpoints.first.options[:route_options][:headers])
            .to eq headers
        end
      end

      context 'when executing a custom block on mount' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            get 'always' do
              'success'
            end

            mounted do
              configuration[:endpoints].each do |endpoint_name, endpoint_response|
                get endpoint_name do
                  endpoint_response
                end
              end
            end
          end
        end

        it 'mounts the endpoints only when configured to do so' do
          root_api.mount a_remounted_api, with: { endpoints: { 'api_name' => 'api_response' } }
          get 'api_name'
          expect(last_response.body).to eq 'api_response'
        end
      end

      context 'when the configuration is part of the arguments of a method' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            get configuration[:endpoint_name] do
              'success'
            end
          end
        end

        it 'mounts the endpoint in the location it is configured' do
          root_api.mount a_remounted_api, with: { endpoint_name: 'some_location' }
          get '/some_location'
          expect(last_response.body).to eq 'success'

          get '/different_location'
          expect(last_response).to be_not_found

          root_api.mount a_remounted_api, with: { endpoint_name: 'new_location' }
          get '/new_location'
          expect(last_response.body).to eq 'success'
        end

        context 'when the configuration is the value in a key-arg pair' do
          subject(:a_remounted_api) do
            Class.new(described_class) do
              version 'v1', using: :param, parameter: configuration[:version_param]
              get 'endpoint' do
                'version 1'
              end

              version 'v2', using: :param, parameter: configuration[:version_param]
              get 'endpoint' do
                'version 2'
              end
            end
          end

          it 'takes the param from the configuration' do
            root_api.mount a_remounted_api, with: { version_param: 'param_name' }

            get '/endpoint?param_name=v1'
            expect(last_response.body).to eq 'version 1'

            get '/endpoint?param_name=v2'
            expect(last_response.body).to eq 'version 2'

            get '/endpoint?wrong_param_name=v2'
            expect(last_response.body).to eq 'version 1'
          end
        end
      end

      context 'on the DescSCope' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            desc 'The description of this' do
              tags ['not_configurable_tag', configuration[:a_configurable_tag]]
            end
            get 'location' do
              route.tags
            end
          end
        end

        it 'mounts the endpoint with the appropiate tags' do
          root_api.mount({ a_remounted_api => 'integer' }, with: { a_configurable_tag: 'a configured tag' })
          get '/integer/location', param_key: 'a'
          expect(JSON.parse(last_response.body)).to eq ['not_configurable_tag', 'a configured tag']
        end
      end

      context 'on the ParamScope' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            params do
              requires configuration[:required_param], type: configuration[:required_type]
            end

            get 'location' do
              'success'
            end
          end
        end

        it 'mounts the endpoint in the location it is configured' do
          root_api.mount({ a_remounted_api => 'string' }, with: { required_param: 'param_key', required_type: String })
          root_api.mount({ a_remounted_api => 'integer' }, with: { required_param: 'param_integer', required_type: Integer })

          get '/string/location', param_key: 'a'
          expect(last_response.body).to eq 'success'

          get '/string/location', param_integer: 1
          expect(last_response).to be_bad_request

          get '/integer/location', param_integer: 1
          expect(last_response.body).to eq 'success'

          get '/integer/location', param_integer: 'a'
          expect(last_response).to be_bad_request
        end

        context 'on dynamic checks' do
          subject(:a_remounted_api) do
            Class.new(described_class) do
              params do
                optional :restricted_values, values: -> { [configuration[:allowed_value], 'always'] }
              end

              get 'location' do
                'success'
              end
            end
          end

          it 'can read the configuration on lambdas' do
            root_api.mount a_remounted_api, with: { allowed_value: 'sometimes' }
            get '/location', restricted_values: 'always'
            expect(last_response.body).to eq 'success'
            get '/location', restricted_values: 'sometimes'
            expect(last_response.body).to eq 'success'
            get '/location', restricted_values: 'never'
            expect(last_response).to be_bad_request
          end
        end
      end

      context 'when the configuration is read within a namespace' do
        before do
          a_remounted_api.namespace 'api' do
            params do
              requires configuration[:required_param]
            end
            get "/#{configuration[:path]}" do
              '10 votes'
            end
          end
          root_api.mount a_remounted_api, with: { path: 'votes', required_param: 'param_key' }
          root_api.mount a_remounted_api, with: { path: 'scores', required_param: 'param_key' }
        end

        it 'uses the dynamic configuration on all routes' do
          get 'api/votes', param_key: 'a'
          expect(last_response.body).to eql '10 votes'
          get 'api/scores', param_key: 'a'
          expect(last_response.body).to eql '10 votes'
          get 'api/votes'
          expect(last_response).to be_bad_request
        end
      end

      context 'a very complex configuration example' do
        before do
          top_level_api = Class.new(described_class) do
            remounted_api = Class.new(Grape::API) do
              get configuration[:endpoint_name] do
                configuration[:response]
              end
            end

            expression_namespace = mounted { configuration[:namespace].to_s * 2 }
            given(mounted { configuration[:should_mount_expressed] != false }) do
              namespace expression_namespace do
                mount remounted_api, with: { endpoint_name: configuration[:endpoint_name], response: configuration[:endpoint_response] }
              end
            end
          end
          root_api.mount top_level_api, with: configuration_options
        end

        context 'when the namespace should be mounted' do
          let(:configuration_options) do
            {
              should_mount_expressed: true,
              namespace: 'bang',
              endpoint_name: 'james',
              endpoint_response: 'bond'
            }
          end

          it 'gets a response' do
            get 'bangbang/james'
            expect(last_response.body).to eq 'bond'
          end
        end

        context 'when should be mounted is nil' do
          let(:configuration_options) do
            {
              should_mount_expressed: nil,
              namespace: 'bang',
              endpoint_name: 'james',
              endpoint_response: 'bond'
            }
          end

          it 'gets a response' do
            get 'bangbang/james'
            expect(last_response.body).to eq 'bond'
          end
        end

        context 'when it should not be mounted' do
          let(:configuration_options) do
            {
              should_mount_expressed: false,
              namespace: 'bang',
              endpoint_name: 'james',
              endpoint_response: 'bond'
            }
          end

          it 'gets a response' do
            get 'bangbang/james'
            expect(last_response.body).not_to eq 'bond'
          end
        end
      end

      context 'when the configuration is read in a helper' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            helpers do
              def printed_response
                configuration[:some_value]
              end
            end

            get 'location' do
              printed_response
            end
          end
        end

        it 'uses the dynamic configuration on all routes' do
          root_api.mount(a_remounted_api, with: { some_value: 'response value' })

          get '/location'
          expect(last_response.body).to eq 'response value'
        end
      end

      context 'when the configuration is read within the response block' do
        subject(:a_remounted_api) do
          Class.new(described_class) do
            get 'location' do
              configuration[:some_value]
            end
          end
        end

        it 'uses the dynamic configuration on all routes' do
          root_api.mount(a_remounted_api, with: { some_value: 'response value' })

          get '/location'
          expect(last_response.body).to eq 'response value'
        end
      end
    end

    context 'with route settings' do
      before do
        a_remounted_api.desc 'Identical description'
        a_remounted_api.route_setting :custom, key: 'value'
        a_remounted_api.route_setting :custom_diff, key: 'foo'
        a_remounted_api.get '/api1' do
          status 200
        end

        a_remounted_api.desc 'Identical description'
        a_remounted_api.route_setting :custom, key: 'value'
        a_remounted_api.route_setting :custom_diff, key: 'bar'
        a_remounted_api.get '/api2' do
          status 200
        end
      end

      it 'has all the settings for both routes' do
        expect(a_remounted_api.routes.count).to be(2)
        expect(a_remounted_api.routes[0].settings).to include(
          {
            description: { description: 'Identical description' },
            custom: { key: 'value' },
            custom_diff: { key: 'foo' }
          }
        )
        expect(a_remounted_api.routes[1].settings).to include(
          {
            description: { description: 'Identical description' },
            custom: { key: 'value' },
            custom_diff: { key: 'bar' }
          }
        )
      end

      context 'when mounting it' do
        before do
          root_api.mount a_remounted_api
        end

        it 'still has all the settings for both routes' do
          expect(root_api.routes.count).to be(2)
          expect(root_api.routes[0].settings).to include(
            {
              description: { description: 'Identical description' },
              custom: { key: 'value' },
              custom_diff: { key: 'foo' }
            }
          )
          expect(root_api.routes[1].settings).to include(
            {
              description: { description: 'Identical description' },
              custom: { key: 'value' },
              custom_diff: { key: 'bar' }
            }
          )
        end
      end
    end
  end
end
