# frozen_string_literal: true

describe Grape::Validations do
  subject { Class.new(Grape::API) }

  let(:app) { subject }
  let(:declared_params) { subject.namespace_stackable(:declared_params).flatten }

  describe 'params' do
    context 'optional' do
      before do
        subject.params do
          optional :a_number, regexp: /^[0-9]+$/
          optional :attachment, type: File
        end
        subject.get '/optional' do
          'optional works!'
        end
      end

      it 'validates when params is present' do
        get '/optional', a_number: 'string'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('a_number is invalid')

        get '/optional', a_number: 45
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional works!')
      end

      it "doesn't validate when param not present" do
        get '/optional', a_number: nil, attachment: nil
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional works!')
      end

      it 'adds to declared parameters' do
        subject.params do
          optional :some_param
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([:some_param])
      end
    end

    context 'optional using Grape::Entity documentation' do
      def define_optional_using
        documentation = { field_a: { type: String }, field_b: { type: String } }
        subject.params do
          optional :all, using: documentation
        end
      end
      before do
        define_optional_using
        subject.get '/optional' do
          'optional with using works'
        end
      end

      it 'adds entity documentation to declared params' do
        define_optional_using
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq(%i[field_a field_b])
      end

      it 'works when field_a and field_b are not present' do
        get '/optional'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional with using works')
      end

      it 'works when field_a is present' do
        get '/optional', field_a: 'woof'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional with using works')
      end

      it 'works when field_b is present' do
        get '/optional', field_b: 'woof'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional with using works')
      end
    end

    context 'required' do
      before do
        subject.params do
          requires :key, type: String
        end
        subject.get('/required') { 'required works' }
        subject.put('/required') { { key: params[:key] }.to_json }
      end

      it 'errors when param not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('key is missing')
      end

      it "doesn't throw a missing param when param is present" do
        get '/required', key: 'cool'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end

      it 'adds to declared parameters' do
        subject.params do
          requires :some_param
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([:some_param])
      end

      it 'works when required field is present but nil' do
        put '/required', { key: nil }.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq('key' => nil)
      end
    end

    context 'requires with nested params' do
      before do
        subject.params do
          requires :first_level, type: Hash do
            optional :second_level, type: Array do
              requires :value, type: Integer
              optional :name, type: String
              optional :third_level, type: Array do
                requires :value, type: Integer
                optional :name, type: String
                optional :fourth_level, type: Array do
                  requires :value, type: Integer
                  optional :name, type: String
                end
              end
            end
          end
        end
        subject.put('/required') { 'required works' }
      end

      let(:request_params) do
        {
          first_level: {
            second_level: [
              { value: 1, name: 'Lisa' },
              {
                value: 2,
                name: 'James',
                third_level: [
                  { value: 'three', name: 'Sophie' },
                  {
                    value: 4,
                    name: 'Jenny',
                    fourth_level: [
                      { name: 'Samuel' }, { value: 6, name: 'Jane' }
                    ]
                  }
                ]
              }
            ]
          }
        }
      end

      it 'validates correctly in deep nested params' do
        put '/required', request_params.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq(
          'first_level[second_level][1][third_level][0][value] is invalid, ' \
          'first_level[second_level][1][third_level][1][fourth_level][0][value] is missing'
        )
      end
    end

    context 'requires :all using Grape::Entity documentation' do
      def define_requires_all
        documentation = {
          required_field: { type: String, required: true, param_type: 'query' },
          optional_field: { type: String },
          optional_array_field: { type: Array[String], is_array: true }
        }
        subject.params do
          requires :all, except: %i[optional_field optional_array_field], using: documentation
        end
      end
      before do
        define_requires_all
        subject.get '/required' do
          'required works'
        end
      end

      it 'adds entity documentation to declared params' do
        define_requires_all
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq(%i[required_field optional_field optional_array_field])
      end

      it 'errors when required_field is not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('required_field is missing')
      end

      it 'works when required_field is present' do
        get '/required', required_field: 'woof'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end
    end

    context 'requires :none using Grape::Entity documentation' do
      def define_requires_none
        documentation = {
          required_field: { type: String, example: 'Foo' },
          optional_field: { type: Integer, format: 'int64' }
        }
        subject.params do
          requires :none, except: :required_field, using: documentation
        end
      end
      before do
        define_requires_none
        subject.get '/required' do
          'required works'
        end
      end

      it 'adds entity documentation to declared params' do
        define_requires_none
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq(%i[required_field optional_field])
      end

      it 'errors when required_field is not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('required_field is missing')
      end

      it 'works when required_field is present' do
        get '/required', required_field: 'woof'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end
    end

    context 'requires :all or :none but except a non-existent field using Grape::Entity documentation' do
      context 'requires :all' do
        def define_requires_all
          documentation = {
            required_field: { type: String },
            optional_field: { type: String }
          }
          subject.params do
            requires :all, except: :non_existent_field, using: documentation
          end
        end

        it 'adds only the entity documentation to declared params, nothing more' do
          define_requires_all
          expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq(%i[required_field optional_field])
        end
      end

      context 'requires :none' do
        def define_requires_none
          documentation = {
            required_field: { type: String },
            optional_field: { type: String }
          }
          subject.params do
            requires :none, except: :non_existent_field, using: documentation
          end
        end

        it 'adds only the entity documentation to declared params, nothing more' do
          expect { define_requires_none }.to raise_error(ArgumentError)
        end
      end
    end

    context 'required with an Array block' do
      before do
        subject.params do
          requires :items, type: Array do
            requires :key
          end
        end
        subject.get('/required') { 'required works' }
        subject.put('/required') { { items: params[:items] }.to_json }
      end

      it 'errors when param not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is missing')
      end

      it 'errors when param is not an Array' do
        get '/required', items: 'hello'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid')

        get '/required', items: { key: 'foo' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid')
      end

      it "doesn't throw a missing param when param is present" do
        get '/required', items: [{ key: 'hello' }, { key: 'world' }]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end

      it "doesn't throw a missing param when param is present but empty" do
        put '/required', { items: [] }.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq('items' => [])
      end

      it 'adds to declared parameters' do
        subject.params do
          requires :items, type: Array do
            requires :key
          end
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([items: [:key]])
      end
    end

    # Ensure there is no leakage between declared Array types and
    # subsequent Hash types
    context 'required with an Array and a Hash block' do
      before do
        subject.params do
          requires :cats, type: Array[String], default: []
          requires :items, type: Hash do
            requires :key
          end
        end
        subject.get '/required' do
          'required works'
        end
      end

      it 'does not output index [0] for Hash types' do
        get '/required', cats: ['Garfield'], items: { foo: 'bar' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[key] is missing')
      end
    end

    context 'required with a Hash block' do
      before do
        subject.params do
          requires :items, type: Hash do
            requires :key
          end
        end
        subject.get '/required' do
          'required works'
        end
      end

      it 'errors when param not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is missing, items[key] is missing')
      end

      it 'errors when nested param not present' do
        get '/required', items: { foo: 'bar' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[key] is missing')
      end

      it 'errors when param is not a Hash' do
        get '/required', items: 'hello'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid, items[key] is missing')

        get '/required', items: [{ key: 'foo' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid')
      end

      it "doesn't throw a missing param when param is present" do
        get '/required', items: { key: 'hello' }
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end

      it 'adds to declared parameters' do
        subject.params do
          requires :items, type: Array do
            requires :key
          end
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([items: [:key]])
      end
    end

    context 'hash with a required param with validation' do
      before do
        subject.params do
          requires :items, type: Hash do
            requires :key, type: String, values: %w[a b]
          end
        end
        subject.get '/required' do
          'required works'
        end
      end

      it 'errors when param is not a Hash' do
        get '/required', items: 'not a hash'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid, items[key] is missing, items[key] is invalid')

        get '/required', items: [{ key: 'hash in array' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid, items[key] does not have a valid value')
      end

      it 'works when all params match' do
        get '/required', items: { key: 'a' }
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end
    end

    context 'group' do
      before do
        subject.params do
          group :items, type: Array do
            requires :key
          end
        end
        subject.get '/required' do
          'required works'
        end
      end

      it 'errors when param not present' do
        get '/required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is missing')
      end

      it "doesn't throw a missing param when param is present" do
        get '/required', items: [key: 'hello']
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('required works')
      end

      it 'adds to declared parameters' do
        subject.params do
          group :items, type: Array do
            requires :key
          end
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([items: [:key]])
      end
    end

    context 'group params with nested params which has a type' do
      let(:invalid_items) { { items: '' } }

      before do
        subject.params do
          optional :items, type: Array do
            optional :key1, type: String
            optional :key2, type: String
          end
        end
        subject.post '/group_with_nested' do
          'group with nested works'
        end
      end

      it 'errors when group param is invalid' do
        post '/group_with_nested', items: invalid_items
        expect(last_response.status).to eq(400)
      end
    end

    context 'custom validator for a Hash' do
      let(:date_range_validator) do
        Class.new(Grape::Validations::Validators::Base) do
          def validate_param!(attr_name, params)
            return if params[attr_name][:from] <= params[attr_name][:to]

            raise Grape::Exceptions::Validation.new(params: [@scope.full_name(attr_name)], message: "'from' must be lower or equal to 'to'")
          end
        end
      end

      before do
        stub_const('DateRangeValidator', date_range_validator)
        described_class.register(DateRangeValidator)
        subject.params do
          optional :date_range, date_range: true, type: Hash do
            requires :from, type: Integer
            requires :to, type: Integer
          end
        end
        subject.get('/optional') do
          'optional works'
        end
        subject.params do
          requires :date_range, date_range: true, type: Hash do
            requires :from, type: Integer
            requires :to, type: Integer
          end
        end
        subject.get('/required') do
          'required works'
        end
      end

      after do
        described_class.deregister(:date_range)
      end

      context 'which is optional' do
        it "doesn't throw an error if the validation passes" do
          get '/optional', date_range: { from: 1, to: 2 }
          expect(last_response.status).to eq(200)
        end

        it 'errors if the validation fails' do
          get '/optional', date_range: { from: 2, to: 1 }
          expect(last_response.status).to eq(400)
        end
      end

      context 'which is required' do
        it "doesn't throw an error if the validation passes" do
          get '/required', date_range: { from: 1, to: 2 }
          expect(last_response.status).to eq(200)
        end

        it 'errors if the validation fails' do
          get '/required', date_range: { from: 2, to: 1 }
          expect(last_response.status).to eq(400)
        end
      end
    end

    context 'validation within arrays' do
      before do
        subject.params do
          group :children, type: Array do
            requires :name
            group :parents, type: Array do
              requires :name, allow_blank: false
            end
          end
        end
        subject.get '/within_array' do
          'within array works'
        end
      end

      it 'can handle new scopes within child elements' do
        get '/within_array', children: [
          { name: 'John', parents: [{ name: 'Jane' }, { name: 'Bob' }] },
          { name: 'Joe', parents: [{ name: 'Josie' }] }
        ]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('within array works')
      end

      it 'errors when a parameter is not present' do
        get '/within_array', children: [
          { name: 'Jim', parents: [{ name: 'Joy' }] },
          { name: 'Job', parents: [{}] }
        ]
        # NOTE: with body parameters in json or XML or similar this
        # should actually fail with: children[parents][name] is missing.
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[1][parents] is missing, children[0][parents][1][name] is missing, children[0][parents][1][name] is empty')
      end

      it 'errors when a parameter is not present in array within array' do
        get '/within_array', children: [
          { name: 'Jim', parents: [{ name: 'Joy' }] },
          { name: 'Job', parents: [{ name: 'Bill' }, { name: '' }] }
        ]

        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[1][parents][1][name] is empty')
      end

      it 'handle errors for all array elements' do
        get '/within_array', children: [
          { name: 'Jim', parents: [] },
          { name: 'Job', parents: [] }
        ]

        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq(
          'children[0][parents][0][name] is missing, ' \
          'children[1][parents][0][name] is missing'
        )
      end

      it 'safely handles empty arrays and blank parameters' do
        # NOTE: with body parameters in json or XML or similar this
        # should actually return 200, since an empty array is valid.
        get '/within_array', children: []
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq(
          'children[0][name] is missing, ' \
          'children[0][parents] is missing, ' \
          'children[0][parents] is invalid, ' \
          'children[0][parents][0][name] is missing, ' \
          'children[0][parents][0][name] is empty'
        )

        get '/within_array', children: [name: 'Jay']
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[0][parents] is missing, children[0][parents][0][name] is missing, children[0][parents][0][name] is empty')
      end

      it 'errors when param is not an Array' do
        get '/within_array', children: 'hello'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children is invalid')

        get '/within_array', children: { name: 'foo' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children is invalid')

        get '/within_array', children: [name: 'Jay', parents: { name: 'Fred' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[0][parents] is invalid')
      end
    end

    context 'with block param' do
      before do
        subject.params do
          requires :planets, type: Array do
            requires :name
          end
        end
        subject.get '/req' do
          'within array works'
        end
        subject.put '/req' do
          ''
        end

        subject.params do
          group :stars, type: Array do
            requires :name
          end
        end
        subject.get '/grp' do
          'within array works'
        end
        subject.put '/grp' do
          ''
        end

        subject.params do
          requires :name
          optional :moons, type: Array do
            requires :name
          end
        end
        subject.get '/opt' do
          'within array works'
        end
        subject.put '/opt' do
          ''
        end
      end

      it 'requires defaults to Array type' do
        get '/req', planets: 'Jupiter, Saturn'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('planets is invalid')

        get '/req', planets: { name: 'Jupiter' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('planets is invalid')

        get '/req', planets: [{ name: 'Venus' }, { name: 'Mars' }]
        expect(last_response.status).to eq(200)

        put_with_json '/req', planets: []
        expect(last_response.status).to eq(200)
      end

      it 'optional defaults to Array type' do
        get '/opt', name: 'Jupiter', moons: 'Europa, Ganymede'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('moons is invalid')

        get '/opt', name: 'Jupiter', moons: { name: 'Ganymede' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('moons is invalid')

        get '/opt', name: 'Jupiter', moons: [{ name: 'Io' }, { name: 'Callisto' }]
        expect(last_response.status).to eq(200)

        put_with_json '/opt', name: 'Venus'
        expect(last_response.status).to eq(200)

        put_with_json '/opt', name: 'Mercury', moons: []
        expect(last_response.status).to eq(200)
      end

      it 'group defaults to Array type' do
        get '/grp', stars: 'Sun'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('stars is invalid')

        get '/grp', stars: { name: 'Sun' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('stars is invalid')

        get '/grp', stars: [{ name: 'Sun' }]
        expect(last_response.status).to eq(200)

        put_with_json '/grp', stars: []
        expect(last_response.status).to eq(200)
      end
    end

    context 'validation within arrays with JSON' do
      before do
        subject.params do
          group :children, type: Array do
            requires :name
            group :parents, type: Array do
              requires :name
            end
          end
        end
        subject.put '/within_array' do
          'within array works'
        end
      end

      it 'can handle new scopes within child elements' do
        put_with_json '/within_array', children: [
          { name: 'John', parents: [{ name: 'Jane' }, { name: 'Bob' }] },
          { name: 'Joe', parents: [{ name: 'Josie' }] }
        ]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('within array works')
      end

      it 'errors when a parameter is not present' do
        put_with_json '/within_array', children: [
          { name: 'Jim', parents: [{}] },
          { name: 'Job', parents: [{ name: 'Joy' }] }
        ]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[0][parents][0][name] is missing')
      end

      it 'safely handles empty arrays and blank parameters' do
        put_with_json '/within_array', children: []
        expect(last_response.status).to eq(200)
        put_with_json '/within_array', children: [name: 'Jay']
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('children[0][parents] is missing, children[0][parents][0][name] is missing')
      end
    end

    context 'optional with an Array block' do
      before do
        subject.params do
          optional :items, type: Array do
            requires :key
          end
        end
        subject.get '/optional_group' do
          'optional group works'
        end
      end

      it "doesn't throw a missing param when the group isn't present" do
        get '/optional_group'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional group works')
      end

      it "doesn't throw a missing param when both group and param are given" do
        get '/optional_group', items: [{ key: 'foo' }]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('optional group works')
      end

      it 'errors when group is present, but required param is not' do
        get '/optional_group', items: [{ not_key: 'foo' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[0][key] is missing')
      end

      it "errors when param is present but isn't an Array" do
        get '/optional_group', items: 'hello'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid')

        get '/optional_group', items: { key: 'foo' }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items is invalid')
      end

      it 'adds to declared parameters' do
        subject.params do
          optional :items, type: Array do
            requires :key
          end
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([items: [:key]])
      end
    end

    context 'nested optional Array blocks' do
      before do
        subject.params do
          optional :items, type: Array do
            requires :key
            optional(:optional_subitems, type: Array) { requires :value }
            requires(:required_subitems, type: Array) { requires :value }
          end
        end
        subject.get('/nested_optional_group') { 'nested optional group works' }
      end

      it 'does no internal validations if the outer group is blank' do
        get '/nested_optional_group'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('nested optional group works')
      end

      it 'does internal validations if the outer group is present' do
        get '/nested_optional_group', items: [{ key: 'foo' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[0][required_subitems] is missing, items[0][required_subitems][0][value] is missing')

        get '/nested_optional_group', items: [{ key: 'foo', required_subitems: [{ value: 'bar' }] }]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('nested optional group works')
      end

      it 'handles deep nesting' do
        get '/nested_optional_group', items: [{ key: 'foo', required_subitems: [{ value: 'bar' }], optional_subitems: [{ not_value: 'baz' }] }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[0][optional_subitems][0][value] is missing')

        get '/nested_optional_group', items: [{ key: 'foo', required_subitems: [{ value: 'bar' }], optional_subitems: [{ value: 'baz' }] }]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('nested optional group works')
      end

      it 'handles validation within arrays' do
        get '/nested_optional_group', items: [{ key: 'foo' }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[0][required_subitems] is missing, items[0][required_subitems][0][value] is missing')

        get '/nested_optional_group', items: [{ key: 'foo', required_subitems: [{ value: 'bar' }] }]
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('nested optional group works')

        get '/nested_optional_group', items: [{ key: 'foo', required_subitems: [{ value: 'bar' }], optional_subitems: [{ not_value: 'baz' }] }]
        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq('items[0][optional_subitems][0][value] is missing')
      end

      it 'adds to declared parameters' do
        subject.params do
          optional :items, type: Array do
            requires :key
            optional(:optional_subitems, type: Array) { requires :value }
            requires(:required_subitems, type: Array) { requires :value }
          end
        end
        expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq([items: [:key, { optional_subitems: [:value] }, { required_subitems: [:value] }]])
      end

      context <<~DESC do
        Issue occurs whenever:
        * param structure with at least three levels
        * 1st level item is a required Array that has >1 entry with an optional item present and >1 entry with an optional item missing#{'  '}
        * 2nd level is an optional Array or Hash#{' '}
        * 3rd level is a required item (can be any type)
        * additional levels do not effect the issue from occuring
      DESC

        it 'example based off actual real world use case' do
          subject.params do
            requires :orders, type: Array do
              requires :id, type: Integer
              optional :drugs, type: Array do
                requires :batches, type: Array do
                  requires :batch_no, type: String
                end
              end
            end
          end

          subject.get '/validate_required_arrays_under_optional_arrays' do
            'validate_required_arrays_under_optional_arrays works!'
          end

          data = {
            orders: [
              { id: 77, drugs: [{ batches: [{ batch_no: 'A1234567' }] }] },
              { id: 70 }
            ]
          }

          get '/validate_required_arrays_under_optional_arrays', data
          expect(last_response.body).to eq('validate_required_arrays_under_optional_arrays works!')
          expect(last_response.status).to eq(200)
        end

        it 'simplest example using Array -> Array -> Hash -> String' do
          subject.params do
            requires :orders, type: Array do
              requires :id, type: Integer
              optional :drugs, type: Array do
                requires :batch_no, type: String
              end
            end
          end

          subject.get '/validate_required_arrays_under_optional_arrays' do
            'validate_required_arrays_under_optional_arrays works!'
          end

          data = {
            orders: [
              { id: 77, drugs: [{ batch_no: 'A1234567' }] },
              { id: 70 }
            ]
          }

          get '/validate_required_arrays_under_optional_arrays', data
          expect(last_response.body).to eq('validate_required_arrays_under_optional_arrays works!')
          expect(last_response.status).to eq(200)
        end

        it 'simplest example using Array -> Hash -> String' do
          subject.params do
            requires :orders, type: Array do
              requires :id, type: Integer
              optional :drugs, type: Hash do
                requires :batch_no, type: String
              end
            end
          end

          subject.get '/validate_required_arrays_under_optional_arrays' do
            'validate_required_arrays_under_optional_arrays works!'
          end

          data = {
            orders: [
              { id: 77, drugs: { batch_no: 'A1234567' } },
              { id: 70 }
            ]
          }

          get '/validate_required_arrays_under_optional_arrays', data
          expect(last_response.body).to eq('validate_required_arrays_under_optional_arrays works!')
          expect(last_response.status).to eq(200)
        end

        it 'correctly indexes invalida data' do
          subject.params do
            requires :orders, type: Array do
              requires :id, type: Integer
              optional :drugs, type: Array do
                requires :batch_no, type: String
                requires :quantity, type: Integer
              end
            end
          end

          subject.get '/correctly_indexes' do
            'correctly_indexes works!'
          end

          data = {
            orders: [
              { id: 70 },
              { id: 77, drugs: [{ batch_no: 'A1234567', quantity: 12 }, { batch_no: 'B222222' }] }
            ]
          }

          get '/correctly_indexes', data
          expect(last_response.body).to eq('orders[1][drugs][1][quantity] is missing')
          expect(last_response.status).to eq(400)
        end

        context 'multiple levels of optional and requires settings' do
          before do
            subject.params do
              requires :top, type: Array do
                requires :top_id, type: Integer, allow_blank: false
                optional :middle_1, type: Array do
                  requires :middle_1_id, type: Integer, allow_blank: false
                  optional :middle_2, type: Array do
                    requires :middle_2_id, type: String, allow_blank: false
                    optional :bottom, type: Array do
                      requires :bottom_id, type: Integer, allow_blank: false
                    end
                  end
                end
              end
            end

            subject.get '/multi_level' do
              'multi_level works!'
            end
          end

          it 'with valid data' do
            data = {
              top: [
                { top_id: 1, middle_1: [
                  { middle_1_id: 11 }, { middle_1_id: 12, middle_2: [
                    { middle_2_id: 121 }, { middle_2_id: 122, bottom: [{ bottom_id: 1221 }] }
                  ] }
                ] },
                { top_id: 2, middle_1: [
                  { middle_1_id: 21 }, { middle_1_id: 22, middle_2: [
                    { middle_2_id: 221 }
                  ] }
                ] },
                { top_id: 3, middle_1: [
                  { middle_1_id: 31 }, { middle_1_id: 32 }
                ] },
                { top_id: 4 }
              ]
            }

            get '/multi_level', data
            expect(last_response.body).to eq('multi_level works!')
            expect(last_response.status).to eq(200)
          end

          it 'with invalid data' do
            data = {
              top: [
                { top_id: 1, middle_1: [
                  { middle_1_id: 11 }, { middle_1_id: 12, middle_2: [
                    { middle_2_id: 121 }, { middle_2_id: 122, bottom: [{ bottom_id: nil }] }
                  ] }
                ] },
                { top_id: 2, middle_1: [
                  { middle_1_id: 21 }, { middle_1_id: 22, middle_2: [{ middle_2_id: nil }] }
                ] },
                { top_id: 3, middle_1: [
                  { middle_1_id: nil }, { middle_1_id: 32 }
                ] },
                { top_id: nil, missing_top_id: 4 }
              ]
            }
            # debugger
            get '/multi_level', data
            expect(last_response.body.split(', ')).to contain_exactly(
              'top[3][top_id] is empty',
              'top[2][middle_1][0][middle_1_id] is empty',
              'top[1][middle_1][1][middle_2][0][middle_2_id] is empty',
              'top[0][middle_1][1][middle_2][1][bottom][0][bottom_id] is empty'
            )
            expect(last_response.status).to eq(400)
          end
        end
      end

      it 'exactly_one_of' do
        subject.params do
          requires :orders, type: Array do
            requires :id, type: Integer
            optional :drugs, type: Hash do
              optional :batch_no, type: String
              optional :batch_id, type: String
              exactly_one_of :batch_no, :batch_id
            end
          end
        end

        subject.get '/exactly_one_of' do
          'exactly_one_of works!'
        end

        data = {
          orders: [
            { id: 77, drugs: { batch_no: 'A1234567' } },
            { id: 70 }
          ]
        }

        get '/exactly_one_of', data
        expect(last_response.body).to eq('exactly_one_of works!')
        expect(last_response.status).to eq(200)
      end

      it 'at_least_one_of' do
        subject.params do
          requires :orders, type: Array do
            requires :id, type: Integer
            optional :drugs, type: Hash do
              optional :batch_no, type: String
              optional :batch_id, type: String
              at_least_one_of :batch_no, :batch_id
            end
          end
        end

        subject.get '/at_least_one_of' do
          'at_least_one_of works!'
        end

        data = {
          orders: [
            { id: 77, drugs: { batch_no: 'A1234567' } },
            { id: 70 }
          ]
        }

        get '/at_least_one_of', data
        expect(last_response.body).to eq('at_least_one_of works!')
        expect(last_response.status).to eq(200)
      end

      it 'all_or_none_of' do
        subject.params do
          requires :orders, type: Array do
            requires :id, type: Integer
            optional :drugs, type: Hash do
              optional :batch_no, type: String
              optional :batch_id, type: String
              all_or_none_of :batch_no, :batch_id
            end
          end
        end

        subject.get '/all_or_none_of' do
          'all_or_none_of works!'
        end

        data = {
          orders: [
            { id: 77, drugs: { batch_no: 'A1234567', batch_id: '12' } },
            { id: 70 }
          ]
        }

        get '/all_or_none_of', data
        expect(last_response.body).to eq('all_or_none_of works!')
        expect(last_response.status).to eq(200)
      end
    end

    context 'multiple validation errors' do
      before do
        subject.params do
          requires :yolo
          requires :swag
        end
        subject.get '/two_required' do
          'two required works'
        end
      end

      it 'throws the validation errors' do
        get '/two_required'
        expect(last_response.status).to eq(400)
        expect(last_response.body).to match(/yolo is missing/)
        expect(last_response.body).to match(/swag is missing/)
      end
    end

    context 'custom validation' do
      let(:custom_validator) do
        Class.new(Grape::Validations::Validators::Base) do
          def validate_param!(attr_name, params)
            return if params[attr_name] == 'im custom'

            raise Grape::Exceptions::Validation.new(params: [@scope.full_name(attr_name)], message: 'is not custom!')
          end
        end
      end

      before do
        stub_const('CustomvalidatorValidator', custom_validator)
        described_class.register(CustomvalidatorValidator)
      end

      after do
        described_class.deregister(:customvalidator)
      end

      context 'when using optional with a custom validator' do
        before do
          subject.params do
            optional :custom, customvalidator: true
          end
          subject.get '/optional_custom' do
            'optional with custom works!'
          end
        end

        it 'validates when param is present' do
          get '/optional_custom', custom: 'im custom'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('optional with custom works!')

          get '/optional_custom', custom: 'im wrong'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('custom is not custom!')
        end

        it "skips validation when parameter isn't present" do
          get '/optional_custom'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('optional with custom works!')
        end

        it 'validates with custom validator when param present and incorrect type' do
          subject.params do
            optional :custom, type: String, customvalidator: true
          end

          get '/optional_custom', custom: 123
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('custom is not custom!')
        end
      end

      context 'when using requires with a custom validator' do
        before do
          subject.params do
            requires :custom, customvalidator: true
          end
          subject.get '/required_custom' do
            'required with custom works!'
          end
        end

        it 'validates when param is present' do
          get '/required_custom', custom: 'im wrong, validate me'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('custom is not custom!')

          get '/required_custom', custom: 'im custom'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('required with custom works!')
        end

        it 'validates when param is not present' do
          get '/required_custom'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('custom is missing, custom is not custom!')
        end

        context 'nested namespaces' do
          before do
            subject.params do
              requires :custom, customvalidator: true
            end
            subject.namespace 'nested' do
              get 'one' do
                'validation failed'
              end
              namespace 'nested' do
                get 'two' do
                  'validation failed'
                end
              end
            end
            subject.namespace 'peer' do
              get 'one' do
                'no validation required'
              end
              namespace 'nested' do
                get 'two' do
                  'no validation required'
                end
              end
            end

            subject.namespace 'unrelated' do
              params do
                requires :name
              end
              get 'one' do
                'validation required'
              end

              namespace 'double' do
                get 'two' do
                  'no validation required'
                end
              end
            end
          end

          specify 'the parent namespace uses the validator' do
            get '/nested/one', custom: 'im wrong, validate me'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq('custom is not custom!')
          end

          specify 'the nested namespace inherits the custom validator' do
            get '/nested/nested/two', custom: 'im wrong, validate me'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq('custom is not custom!')
          end

          specify 'peer namespaces does not have the validator' do
            get '/peer/one', custom: 'im not validated'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('no validation required')
          end

          specify 'namespaces nested in peers should also not have the validator' do
            get '/peer/nested/two', custom: 'im not validated'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('no validation required')
          end

          specify 'when nested, specifying a route should clear out the validations for deeper nested params' do
            get '/unrelated/one'
            expect(last_response.status).to eq(400)
            get '/unrelated/double/two'
            expect(last_response.status).to eq(200)
          end
        end
      end

      context 'when using options on param' do
        let(:custom_validator_with_options) do
          Class.new(Grape::Validations::Validators::Base) do
            def validate_param!(attr_name, params)
              return if params[attr_name] == @option[:text]

              raise Grape::Exceptions::Validation.new(params: [@scope.full_name(attr_name)], message: message)
            end
          end
        end

        before do
          stub_const('CustomvalidatorWithOptionsValidator', custom_validator_with_options)
          described_class.register(CustomvalidatorWithOptionsValidator)
          subject.params do
            optional :custom, customvalidator_with_options: { text: 'im custom with options', message: 'is not custom with options!' }
          end
          subject.get '/optional_custom' do
            'optional with custom works!'
          end
        end

        after do
          described_class.deregister(:customvalidator_with_options)
        end

        it 'validates param with custom validator with options' do
          get '/optional_custom', custom: 'im custom with options'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('optional with custom works!')

          get '/optional_custom', custom: 'im wrong'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('custom is not custom with options!')
        end
      end
    end

    context 'named' do
      context 'can be included in usual params' do
        before do
          shared_params = Module.new do
            extend Grape::DSL::Helpers::BaseHelper
            params :period do
              optional :start_date
              optional :end_date
            end
          end

          subject.helpers shared_params

          subject.helpers do
            params :pagination do
              optional :page, type: Integer
              optional :per_page, type: Integer
            end
          end
        end

        it 'by #use' do
          subject.params do
            use :pagination
          end
          expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq %i[page per_page]
        end

        it 'by #use with multiple params' do
          subject.params do
            use :pagination, :period
          end
          expect(Grape::Validations::ParamsScope::Attr.attrs_keys(declared_params)).to eq %i[page per_page start_date end_date]
        end
      end

      context 'with block' do
        before do
          subject.helpers do
            params :order do |options|
              optional :order, type: Symbol, values: %i[asc desc], default: options[:default_order]
              optional :order_by, type: Symbol, values: options[:order_by], default: options[:default_order_by]
            end
          end
          subject.format :json
          subject.params do
            use :order, default_order: :asc, order_by: %i[name created_at], default_order_by: :created_at
          end
          subject.get '/order' do
            {
              order: params[:order],
              order_by: params[:order_by]
            }
          end
        end

        it 'returns defaults' do
          get '/order'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq({ order: :asc, order_by: :created_at }.to_json)
        end

        it 'overrides default value for order' do
          get '/order?order=desc'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq({ order: :desc, order_by: :created_at }.to_json)
        end

        it 'overrides default value for order_by' do
          get '/order?order_by=name'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq({ order: :asc, order_by: :name }.to_json)
        end

        it 'fails with invalid value' do
          get '/order?order=invalid'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('{"error":"order does not have a valid value"}')
        end
      end
    end

    context 'with block and keyword argument' do
      before do
        subject.helpers do
          params :shared_params do |type:|
            optional :param, default: type
          end
        end
        subject.format :json
        subject.params do
          use :shared_params, type: 'value'
        end
        subject.get '/shared_params' do
          {
            param: params[:param]
          }
        end
      end

      it 'works' do
        get '/shared_params'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq({ param: 'value' }.to_json)
      end
    end

    context 'with block and empty args' do
      before do
        subject.helpers do
          params :shared_params do |empty_args|
            optional :param, default: empty_args[:some]
          end
        end
        subject.format :json
        subject.params do
          use :shared_params
        end
        subject.get '/shared_params' do
          :ok
        end
      end

      it 'works' do
        get '/shared_params'

        expect(last_response.status).to eq(200)
      end
    end

    context 'all or none' do
      context 'optional params' do
        before do
          subject.resource :custom_message do
            params do
              optional :beer
              optional :wine
              optional :juice
              all_or_none_of :beer, :wine, :juice, message: 'all params are required or none is required'
            end
            get '/all_or_none' do
              'all_or_none works!'
            end
          end
        end

        context 'with a custom validation message' do
          it 'errors when any one is present' do
            get '/custom_message/all_or_none', beer: 'string'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq 'beer, wine, juice all params are required or none is required'
          end

          it 'works when all params are present' do
            get '/custom_message/all_or_none', beer: 'string', wine: 'anotherstring', juice: 'anotheranotherstring'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq 'all_or_none works!'
          end

          it 'works when none are present' do
            get '/custom_message/all_or_none'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq 'all_or_none works!'
          end
        end
      end
    end

    context 'mutually exclusive' do
      context 'optional params' do
        context 'with custom validation message' do
          it 'errors when two or more are present' do
            subject.resources :custom_message do
              params do
                optional :beer
                optional :wine
                optional :juice
                mutually_exclusive :beer, :wine, :juice, message: 'are mutually exclusive cannot pass both params'
              end
              get '/mutually_exclusive' do
                'mutually_exclusive works!'
              end
            end
            get '/custom_message/mutually_exclusive', beer: 'string', wine: 'anotherstring'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq 'beer, wine are mutually exclusive cannot pass both params'
          end
        end

        it 'errors when two or more are present' do
          subject.params do
            optional :beer
            optional :wine
            optional :juice
            mutually_exclusive :beer, :wine, :juice
          end
          subject.get '/mutually_exclusive' do
            'mutually_exclusive works!'
          end

          get '/mutually_exclusive', beer: 'string', wine: 'anotherstring'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'beer, wine are mutually exclusive'
        end
      end

      context 'more than one set of mutually exclusive params' do
        context 'with a custom validation message' do
          it 'errors for all sets' do
            subject.resources :custom_message do
              params do
                optional :beer
                optional :wine
                mutually_exclusive :beer, :wine, message: 'are mutually exclusive pass only one'
                optional :nested, type: Hash do
                  optional :scotch
                  optional :aquavit
                  mutually_exclusive :scotch, :aquavit, message: 'are mutually exclusive pass only one'
                end
                optional :nested2, type: Array do
                  optional :scotch2
                  optional :aquavit2
                  mutually_exclusive :scotch2, :aquavit2, message: 'are mutually exclusive pass only one'
                end
              end
              get '/mutually_exclusive' do
                'mutually_exclusive works!'
              end
            end
            get '/custom_message/mutually_exclusive', beer: 'true', wine: 'true', nested: { scotch: 'true', aquavit: 'true' }, nested2: [{ scotch2: 'true' }, { scotch2: 'true', aquavit2: 'true' }]
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq(
              'beer, wine are mutually exclusive pass only one, nested[scotch], nested[aquavit] are mutually exclusive pass only one, nested2[1][scotch2], nested2[1][aquavit2] are mutually exclusive pass only one'
            )
          end
        end

        it 'errors for all sets' do
          subject.params do
            optional :beer
            optional :wine
            mutually_exclusive :beer, :wine
            optional :nested, type: Hash do
              optional :scotch
              optional :aquavit
              mutually_exclusive :scotch, :aquavit
            end
            optional :nested2, type: Array do
              optional :scotch2
              optional :aquavit2
              mutually_exclusive :scotch2, :aquavit2
            end
          end
          subject.get '/mutually_exclusive' do
            'mutually_exclusive works!'
          end

          get '/mutually_exclusive', beer: 'true', wine: 'true', nested: { scotch: 'true', aquavit: 'true' }, nested2: [{ scotch2: 'true' }, { scotch2: 'true', aquavit2: 'true' }]
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'beer, wine are mutually exclusive, nested[scotch], nested[aquavit] are mutually exclusive, nested2[1][scotch2], nested2[1][aquavit2] are mutually exclusive'
        end
      end

      context 'in a group' do
        it 'works when only one from the set is present' do
          subject.params do
            group :drink, type: Hash do
              optional :wine
              optional :beer
              optional :juice
              mutually_exclusive :beer, :wine, :juice
            end
          end
          subject.get '/mutually_exclusive_group' do
            'mutually_exclusive_group works!'
          end

          get '/mutually_exclusive_group', drink: { beer: 'true' }
          expect(last_response.status).to eq(200)
        end

        it 'errors when more than one from the set is present' do
          subject.params do
            group :drink, type: Hash do
              optional :wine
              optional :beer
              optional :juice

              mutually_exclusive :beer, :wine, :juice
            end
          end
          subject.get '/mutually_exclusive_group' do
            'mutually_exclusive_group works!'
          end

          get '/mutually_exclusive_group', drink: { beer: 'true', juice: 'true', wine: 'true' }
          expect(last_response.status).to eq(400)
        end
      end

      context 'mutually exclusive params inside Hash group' do
        it 'invalidates if request param is invalid type' do
          subject.params do
            optional :wine, type: Hash do
              optional :grape
              optional :country
              mutually_exclusive :grape, :country
            end
          end
          subject.post '/mutually_exclusive' do
            'mutually_exclusive works!'
          end

          post '/mutually_exclusive', wine: '2015 sauvignon'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'wine is invalid'
        end
      end
    end

    context 'exactly one of' do
      context 'params' do
        before do
          subject.resources :custom_message do
            params do
              optional :beer
              optional :wine
              optional :juice
              exactly_one_of :beer, :wine, :juice, message: 'are missing, exactly one parameter is required'
            end
            get '/exactly_one_of' do
              'exactly_one_of works!'
            end
          end

          subject.params do
            optional :beer
            optional :wine
            optional :juice
            exactly_one_of :beer, :wine, :juice
          end
          subject.get '/exactly_one_of' do
            'exactly_one_of works!'
          end
        end

        context 'with a custom validation message' do
          it 'errors when none are present' do
            get '/custom_message/exactly_one_of'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq 'beer, wine, juice are missing, exactly one parameter is required'
          end

          it 'succeeds when one is present' do
            get '/custom_message/exactly_one_of', beer: 'string'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq 'exactly_one_of works!'
          end

          it 'errors when two or more are present' do
            get '/custom_message/exactly_one_of', beer: 'string', wine: 'anotherstring'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq 'beer, wine are missing, exactly one parameter is required'
          end
        end

        it 'errors when none are present' do
          get '/exactly_one_of'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'beer, wine, juice are missing, exactly one parameter must be provided'
        end

        it 'succeeds when one is present' do
          get '/exactly_one_of', beer: 'string'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'exactly_one_of works!'
        end

        it 'errors when two or more are present' do
          get '/exactly_one_of', beer: 'string', wine: 'anotherstring'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'beer, wine are mutually exclusive'
        end
      end

      context 'nested params' do
        before do
          subject.params do
            requires :nested, type: Hash do
              optional :beer_nested
              optional :wine_nested
              optional :juice_nested
              exactly_one_of :beer_nested, :wine_nested, :juice_nested
            end
            optional :nested2, type: Array do
              optional :beer_nested2
              optional :wine_nested2
              optional :juice_nested2
              exactly_one_of :beer_nested2, :wine_nested2, :juice_nested2
            end
          end
          subject.get '/exactly_one_of_nested' do
            'exactly_one_of works!'
          end
        end

        it 'errors when none are present' do
          get '/exactly_one_of_nested'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'nested is missing, nested[beer_nested], nested[wine_nested], nested[juice_nested] are missing, exactly one parameter must be provided'
        end

        it 'succeeds when one is present' do
          get '/exactly_one_of_nested', nested: { beer_nested: 'string' }
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'exactly_one_of works!'
        end

        it 'errors when two or more are present' do
          get '/exactly_one_of_nested', nested: { beer_nested: 'string' }, nested2: [{ beer_nested2: 'string', wine_nested2: 'anotherstring' }]
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'nested2[0][beer_nested2], nested2[0][wine_nested2] are mutually exclusive'
        end
      end
    end

    context 'at least one of' do
      context 'params' do
        before do
          subject.resources :custom_message do
            params do
              optional :beer
              optional :wine
              optional :juice
              at_least_one_of :beer, :wine, :juice, message: 'are missing, please specify at least one param'
            end
            get '/at_least_one_of' do
              'at_least_one_of works!'
            end
          end

          subject.params do
            optional :beer
            optional :wine
            optional :juice
            at_least_one_of :beer, :wine, :juice
          end
          subject.get '/at_least_one_of' do
            'at_least_one_of works!'
          end
        end

        context 'with a custom validation message' do
          it 'errors when none are present' do
            get '/custom_message/at_least_one_of'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to eq 'beer, wine, juice are missing, please specify at least one param'
          end

          it 'does not error when one is present' do
            get '/custom_message/at_least_one_of', beer: 'string'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq 'at_least_one_of works!'
          end

          it 'does not error when two are present' do
            get '/custom_message/at_least_one_of', beer: 'string', wine: 'string'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq 'at_least_one_of works!'
          end
        end

        it 'errors when none are present' do
          get '/at_least_one_of'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'beer, wine, juice are missing, at least one parameter must be provided'
        end

        it 'does not error when one is present' do
          get '/at_least_one_of', beer: 'string'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'at_least_one_of works!'
        end

        it 'does not error when two are present' do
          get '/at_least_one_of', beer: 'string', wine: 'string'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'at_least_one_of works!'
        end
      end

      context 'nested params' do
        before do
          subject.params do
            requires :nested, type: Hash do
              optional :beer
              optional :wine
              optional :juice
              at_least_one_of :beer, :wine, :juice
            end
            optional :nested2, type: Array do
              optional :beer
              optional :wine
              optional :juice
              at_least_one_of :beer, :wine, :juice
            end
          end
          subject.get '/at_least_one_of_nested' do
            'at_least_one_of works!'
          end
        end

        it 'errors when none are present' do
          get '/at_least_one_of_nested'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq 'nested is missing, nested[beer], nested[wine], nested[juice] are missing, at least one parameter must be provided'
        end

        it 'does not error when one is present' do
          get '/at_least_one_of_nested', nested: { beer: 'string' }, nested2: [{ beer: 'string' }]
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'at_least_one_of works!'
        end

        it 'does not error when two are present' do
          get '/at_least_one_of_nested', nested: { beer: 'string', wine: 'string' }, nested2: [{ beer: 'string', wine: 'string' }]
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq 'at_least_one_of works!'
        end
      end
    end

    context 'in a group' do
      it 'works when only one from the set is present' do
        subject.params do
          group :drink, type: Hash do
            optional :wine
            optional :beer
            optional :juice

            exactly_one_of :beer, :wine, :juice
          end
        end
        subject.get '/exactly_one_of_group' do
          'exactly_one_of_group works!'
        end

        get '/exactly_one_of_group', drink: { beer: 'true' }
        expect(last_response.status).to eq(200)
      end

      it 'errors when no parameter from the set is present' do
        subject.params do
          group :drink, type: Hash do
            optional :wine
            optional :beer
            optional :juice

            exactly_one_of :beer, :wine, :juice
          end
        end
        subject.get '/exactly_one_of_group' do
          'exactly_one_of_group works!'
        end

        get '/exactly_one_of_group', drink: {}
        expect(last_response.status).to eq(400)
      end

      it 'errors when more than one from the set is present' do
        subject.params do
          group :drink, type: Hash do
            optional :wine
            optional :beer
            optional :juice

            exactly_one_of :beer, :wine, :juice
          end
        end
        subject.get '/exactly_one_of_group' do
          'exactly_one_of_group works!'
        end

        get '/exactly_one_of_group', drink: { beer: 'true', juice: 'true', wine: 'true' }
        expect(last_response.status).to eq(400)
      end

      it 'does not falsely think the param is there if it is provided outside the block' do
        subject.params do
          group :drink, type: Hash do
            optional :wine
            optional :beer
            optional :juice

            exactly_one_of :beer, :wine, :juice
          end
        end
        subject.get '/exactly_one_of_group' do
          'exactly_one_of_group works!'
        end

        get '/exactly_one_of_group', drink: { foo: 'bar' }, beer: 'true'
        expect(last_response.status).to eq(400)
      end
    end

    # Ensure there is no leakage of indices between requests
    context 'required with a hash inside an array' do
      before do
        subject.params do
          requires :items, type: Array do
            requires :item, type: Hash do
              requires :name, type: String
            end
          end
        end
        subject.post '/required' do
          'required works'
        end
      end

      let(:valid_item) { { item: { name: 'foo' } } }

      let(:params) do
        {
          items: [
            valid_item,
            valid_item,
            {}
          ]
        }
      end

      it 'makes sure the error message is independent of the previous request' do
        post_with_json '/required', {}
        expect(last_response).to be_bad_request
        expect(last_response.body).to eq('items is missing, items[item][name] is missing')

        post_with_json '/required', params
        expect(last_response).to be_bad_request
        expect(last_response.body).to eq('items[2][item] is missing, items[2][item][name] is missing')

        post_with_json '/required', {}
        expect(last_response).to be_bad_request
        expect(last_response.body).to eq('items is missing, items[item][name] is missing')
      end
    end
  end

  describe 'require_validator' do
    subject { described_class.require_validator(short_name) }

    context 'when found' do
      let(:short_name) { :presence }

      it { is_expected.to be(Grape::Validations::Validators::PresenceValidator) }
    end

    context 'when not found' do
      let(:short_name) { :test }

      it 'raises an error' do
        expect { subject }.to raise_error(Grape::Exceptions::UnknownValidator)
      end
    end
  end
end
