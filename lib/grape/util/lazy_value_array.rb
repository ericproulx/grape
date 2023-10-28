# frozen_string_literal: true

module Grape
  module Util
    class LazyValueArray < LazyValueEnumerable
      def initialize(array)
        super
        @value_hash = []
        array.each_with_index do |value, index|
          self[index] = value
        end
      end

      def evaluate
        @value_hash.map(&:evaluate)
      end
    end
  end
end
