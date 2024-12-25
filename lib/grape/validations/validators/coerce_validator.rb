# frozen_string_literal: true

module Grape
  module Validations
    module Validators
      class CoerceValidator < Base
        attr_reader :coercer

        def initialize(attrs, options, required, scope, opts)
          super

          @coercer = @option[:coercer]
        end

        def validate_param!(attr_name, params)
          raise validation_exception(attr_name) unless params.is_a? Hash

          new_value = coerce_value(params[attr_name])

          raise validation_exception(attr_name, new_value.message) unless valid_type?(new_value)

          # Don't assign a value if it is identical. It fixes a problem with Hashie::Mash
          # which looses wrappers for hashes and arrays after reassigning values
          #
          #     h = Hashie::Mash.new(list: [1, 2, 3, 4])
          #     => #<Hashie::Mash list=#<Hashie::Array [1, 2, 3, 4]>>
          #     list = h.list
          #     h[:list] = list
          #     h
          #     => #<Hashie::Mash list=[1, 2, 3, 4]>
          return if params[attr_name].instance_of?(new_value.class) && params[attr_name] == new_value

          params[attr_name] = new_value
        end

        private

        def valid_type?(val)
          !val.is_a?(Types::InvalidValue)
        end

        def coerce_value(val)
          coercer.call(val)
          # Some custom types might fail, so it should be treated as an invalid value
        rescue StandardError
          Types::InvalidValue.new
        end

        def validation_exception(attr_name, custom_msg = nil)
          Grape::Exceptions::Validation.new(
            params: [@scope.full_name(attr_name)],
            message: custom_msg || message(:coerce)
          )
        end
      end
    end
  end
end
