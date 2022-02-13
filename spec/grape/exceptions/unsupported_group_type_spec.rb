# frozen_string_literal: true

RSpec.describe Grape::Exceptions::UnsupportedGroupType do
  subject { described_class.new }

  describe '#message' do
    subject { described_class.new.message }

    it { is_expected.to include 'group type must be Array, Hash, JSON or Array[JSON]' }
  end

  describe '#alias' do
    subject { described_class }

    it { is_expected.to eq(Grape::Exceptions::UnsupportedGroupTypeError) }
  end
end