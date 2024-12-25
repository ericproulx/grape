# frozen_string_literal: true

describe Grape::Validations::Types do
  let(:foo_type) do
    Class.new do
      def self.parse(_); end
    end
  end
  let(:bar_type) do
    Class.new do
      def self.parse; end
    end
  end

  describe '::primitive?' do
    [
      Integer, Float, Numeric, BigDecimal,
      Grape::API::Boolean, String, Symbol,
      Date, DateTime, Time
    ].each do |type|
      it "recognizes #{type} as a primitive" do
        expect(described_class).to be_primitive(type)
      end
    end

    it 'identifies unknown types' do
      expect(described_class).not_to be_primitive(Object)
      expect(described_class).not_to be_primitive(foo_type)
    end
  end

  describe '::structure?' do
    [
      Hash, Array, Set
    ].each do |type|
      it "recognizes #{type} as a structure" do
        expect(described_class).to be_structure(type)
      end
    end
  end

  describe '::special?' do
    [
      JSON, Array[JSON], File, Rack::Multipart::UploadedFile
    ].each do |type|
      it "provides special handling for #{type.inspect}" do
        expect(described_class).to be_special(type)
      end
    end
  end

  describe 'special types' do
    subject { described_class::SPECIAL[type] }

    context 'when JSON' do
      let(:type) { JSON }

      it { is_expected.to eq(Grape::Validations::Types::Json) }
    end

    context 'when Array[JSON]' do
      let(:type) { Array[JSON] }

      it { is_expected.to eq(Grape::Validations::Types::JsonArray) }
    end

    context 'when File' do
      let(:type) { File }

      it { is_expected.to eq(Grape::Validations::Types::File) }
    end

    context 'when Rack::Multipart::UploadedFile' do
      let(:type) { Rack::Multipart::UploadedFile }

      it { is_expected.to eq(Grape::Validations::Types::File) }
    end
  end

  describe '::custom?' do
    it 'returns false if the type does not respond to :parse' do
      expect(described_class).not_to be_custom(Object)
    end

    it 'returns true if the type responds to :parse with one argument' do
      expect(described_class).to be_custom(foo_type)
    end

    it 'returns false if the type\'s #parse method takes other than one argument' do
      expect(described_class).not_to be_custom(bar_type)
    end
  end

  describe '::build_coercer' do
    it 'caches the result of the build_coercer method' do
      a_coercer = described_class.build_coercer(Array[String])
      b_coercer = described_class.build_coercer(Array[String])

      expect(a_coercer.object_id).to eq(b_coercer.object_id)
    end
  end
end
