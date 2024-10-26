# frozen_string_literal: true

module Grape
  module Exceptions
    class Validation < Grape::Exceptions::Base
      attr_accessor :params, :message_key

      def initialize(params:, message: nil, status: nil, headers: nil)
        @params = params
        translated_message =
          if message
            @message_key = message if message.is_a?(Symbol)
            translate_message(message)
          else
            message
          end
        super(status: status, headers: headers, message: translated_message)

      end

      # Remove all the unnecessary stuff from Grape::Exceptions::Base like status
      # and headers when converting a validation error to json or string
      def as_json(*_args)
        to_s
      end
    end
  end
end
